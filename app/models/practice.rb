# frozen_string_literal: true

class Practice < ApplicationRecord
  # PaperTrail for audit logging
  has_paper_trail meta: { practice_id: ->(practice) { practice.id } }

  # associations
  has_many :users, dependent: :delete_all # didn't work with :destroy 'cause if the before_destroy callback in User.rb
  has_many :datebooks, dependent: :delete_all
  has_many :doctors, dependent: :destroy
  has_many :patients, dependent: :destroy # uses :destroy so User.rb deletes_all its children
  has_many :treatments, dependent: :delete_all
  has_one :subscription, dependent: :destroy
  PROFILE_PICTURE_MAX_PER_PRACTICE = 500
  PROFILE_PICTURE_MAX_WITHOUT_SUBSCRIPTION = 5

  accepts_nested_attributes_for :users, limit: 1

  # validations
  validates_presence_of :name, :timezone, :locale, :currency
  validates_presence_of :email, on: :update
  validates_uniqueness_of :email
  validates_inclusion_of :currency, in: %w[mxn cad usd eur]
  validates :custom_review_url, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]) }, allow_blank: true

  # callbacks
  before_validation :set_timezone_and_locale, on: :create
  before_validation :set_first_user_data, on: :create
  after_create :create_first_datebook, :create_trial_subscription
  before_create :set_email_practice

  def set_as_cancelled
    self.cancelled_at = Time.now
  end

  def status
    if cancelled_at.nil?
      'active'
    else
      'cancelled'
    end
  end

  def populate_default_treatments
    locale_key = locale.presence || 'en'
    treatments_config = Rails.configuration.patient_treatments[locale_key] || Rails.configuration.patient_treatments['en']
    return unless treatments_config

    treatments_config['treatments'].each do |treatment|
      treatments << Treatment.new(name: treatment, price: 0)
    end
  end

  def has_linked_subscription?
    !stripe_customer_id.nil?
  end

  def has_active_subscription?
    subscription = Subscription.find_by(practice: id, status: 'active')

    return true if subscription.present?

    false
  end

  def profile_picture_upload_limit
    has_active_subscription? ? PROFILE_PICTURE_MAX_PER_PRACTICE : PROFILE_PICTURE_MAX_WITHOUT_SUBSCRIPTION
  end

  # Stripe Connect methods
  def has_connect_account?
    !stripe_account_id.nil?
  end

  def connect_account_complete?
    has_connect_account? && connect_charges_enabled? && connect_payouts_enabled?
  end

  def create_connect_account!
    return if has_connect_account?

    begin
      account = Stripe::Account.create({
                                         type: 'express',
                                         #  country: 'US', # Could be made configurable
                                         email: email,
                                         # entity_type: 'company', # Could be made configurable
                                         metadata: {
                                           practice_id: id.to_s,
                                           practice_name: name
                                         }
                                       })

      update!(
        stripe_account_id: account.id,
        connect_onboarding_status: 'pending'
      )

      account
    rescue Stripe::StripeError => e
      Rails.logger.error "Failed to create Stripe Connect account for practice #{id}: #{e.message}"
      raise e
    end
  end

  def create_connect_onboarding_link(return_url, refresh_url)
    raise 'No Connect account found' unless has_connect_account?

    begin
      Stripe::AccountLink.create({
                                   account: stripe_account_id,
                                   return_url: return_url,
                                   refresh_url: refresh_url,
                                   type: 'account_onboarding'
                                 })
    rescue Stripe::StripeError => e
      Rails.logger.error "Failed to create onboarding link for practice #{id}: #{e.message}"
      raise e
    end
  end

  def refresh_connect_account_status!
    return unless has_connect_account?

    begin
      account = Stripe::Account.retrieve(stripe_account_id)

      update!(
        connect_charges_enabled: account.charges_enabled,
        connect_payouts_enabled: account.payouts_enabled,
        connect_details_submitted: account.details_submitted,
        connect_onboarding_status: determine_onboarding_status_from_stripe_account(account)
      )

      account
    rescue Stripe::StripeError => e
      Rails.logger.error "Failed to refresh Connect account status for practice #{id}: #{e.message}"
      raise e
    end
  end

  def determine_onboarding_status_from_stripe_account(account)
    if account.details_submitted && account.charges_enabled && account.payouts_enabled
      'complete'
    elsif account.verification.disabled_reason.present?
      'disabled'
    elsif account.details_submitted
      'pending_review'
    else
      'not_started'
    end
  end

  private

  def set_email_practice
    self.email = users.first.email
  end

  def set_timezone_and_locale
    begin
      # parse the [Continent]/[City_Name] into [City Name]
      timezone_without_continent = timezone.split('/').last.sub('_', ' ')
      # check if the parsed city name is part of the locales
      self.timezone = if ActiveSupport::TimeZone.all.map(&:name).include? timezone_without_continent
                        timezone_without_continent
                      else
                        Time.zone.name
                      end
    rescue StandardError
      self.timezone = Time.zone.name
    end

    self.locale = 'en'
  end

  def set_first_user_data
    users.first.firstname = I18n.t :administrator
    users.first.lastname = (I18n.t :user).downcase
  end

  def create_first_datebook
    Datebook.create({ practice_id: id, name: I18n.t(:your_first_datebook) })
  end

  def create_trial_subscription
    Subscription.create(
      practice_id: id,
      status: 'trialing',
      cancel_at_period_end: false,
      current_period_start: Time.now,
      current_period_end: 30.days.from_now
    )
  end
end
