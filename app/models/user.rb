# frozen_string_literal: true

class User < ApplicationRecord
  # audit logging
  has_paper_trail meta: { practice_id: lambda(&:practice_id) },
                  skip: %i[password_digest perishable_token remember_token remember_token_expires_at]

  # concerns
  include Initials

  # associations
  belongs_to :practice, counter_cache: true
  has_many :notes, dependent: :delete_all
  has_many :dismissed_announcements, dependent: :delete_all

  has_secure_password

  # named scopes
  scope :with_practice, lambda { |practice_id|
    where('users.practice_id = ? ', practice_id)
  }

  # validations
  validates_presence_of :firstname, :lastname, :email, :roles
  validates_uniqueness_of :email
  validates :email, format: { with: /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z/i }
  validates :firstname, :lastname, length: { maximum: 20 }
  validates :password, length: { minimum: 7 }, if: :validate_password?
  validates :password_confirmation, length: { minimum: 7 }, if: :validate_password?
  validate :prevent_superadmin_elevation

  # callbacks
  before_create :set_admin_role_for_first_user
  before_update :reset_perishable_token
  before_destroy :check_if_admin
  after_update :clear_remember_tokens_on_password_change

  def fullname
    [firstname, lastname].join(' ')
  end

  def preferred_language
    Practice.find(practice_id).locale
  end

  def deliver_password_reset_instructions!
    reset_perishable_token!
    NotifierMailer.deliver_password_reset_instructions(self).deliver_now
  end

  def is_admin?
    roles.include?('admin')
  end

  # Remember token functionality for persistent login
  def remember_me!
    self.remember_token = SecureRandom.urlsafe_base64(32)
    self.remember_token_expires_at = 2.weeks.from_now
    save!(validate: false)
  end

  def forget_me!
    self.remember_token = nil
    self.remember_token_expires_at = nil
    save!(validate: false)
  end

  def remember_token_valid?
    remember_token.present? && remember_token_expires_at.present? && Time.current < remember_token_expires_at
  end

  private

  def validate_password?
    password.present? && password_confirmation.present?
  end

  def check_if_admin
    return unless is_admin?

    errors[:base] << I18n.t('errors.messages.unauthorised')
    false
  end

  def set_admin_role_for_first_user
    self.roles = 'admin' if User.where('practice_id = ?', practice_id).count.zero?
  end

  def reset_perishable_token
    self.perishable_token = SecureRandom.urlsafe_base64(15)
  end

  def reset_perishable_token!
    update_attribute(:perishable_token, SecureRandom.urlsafe_base64(15))
  end

  def clear_remember_tokens_on_password_change
    return unless saved_change_to_password_digest?

    self.remember_token = nil
    self.remember_token_expires_at = nil
    update_columns(remember_token: nil, remember_token_expires_at: nil)
  end

  def prevent_superadmin_elevation
    return unless roles&.include?('superadmin')

    # Allow if this record is already persisted as superadmin in the DB (fixtures/seeds)
    already_superadmin = id.present? && User.where(id: id, roles: 'superadmin').exists?
    return if already_superadmin

    errors.add(:roles, I18n.t('errors.messages.unauthorised'))
  end
end
