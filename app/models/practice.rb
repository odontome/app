# frozen_string_literal: true

class Practice < ApplicationRecord
  # associations
  has_many :users, dependent: :delete_all # didn't work with :destroy 'cause if the before_destroy callback in User.rb
  has_many :datebooks, dependent: :delete_all
  has_many :doctors, dependent: :delete_all
  has_many :patients, dependent: :destroy # uses :destroy so User.rb deletes_all its children
  has_many :treatments, dependent: :delete_all
  has_one :subscription, dependent: :destroy

  accepts_nested_attributes_for :users, limit: 1

  # scopes
  scope :ids_in_timezone, lambda { |timezones|
    select(:id)
    .where(timezone: timezones)
    .pluck(:id)
  }

  # validations
  validates_presence_of :name, :timezone, :locale
  validates_presence_of :email, on: :update
  validates_uniqueness_of :email

  # callbacks
  before_validation :set_timezone_and_locale, on: :create
  before_validation :set_first_user_data, on: :create
  after_create :create_first_datebook, :create_trial_subscription
  before_create :set_email_practice

  def set_as_cancelled
    self.cancelled_at = Time.now
  end

  def status
    if self.cancelled_at.nil?
      'active'
    else
      'cancelled'
    end
  end

  def populate_default_treatments
    Rails.configuration.patient_treatments[locale || 'en']['treatments'].each do |treatment|
      treatments << Treatment.new(name: treatment, price: 0)
    end
  end

  def has_linked_subscription?
    !self.stripe_customer_id.nil?
  end

  def has_active_subscription?
    subscription = Subscription.find_by(practice: id, status: "active")

    if subscription.present?
      return true
    else
      return false
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

  def practice_params
    params.require(:practice).permit(:name, :users_attributes, :locale, :timezone, :currency_unit, :email)
  end
end
