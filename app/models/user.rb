# frozen_string_literal: true

class User < ApplicationRecord
  # audit logging
  has_paper_trail meta: { practice_id: lambda(&:practice_id) },
                  skip: %i[password_digest perishable_token remember_token_digest remember_token_expires_at session_token]

  # concerns
  include Initials
  include ProfileImageable

  # associations
  belongs_to :practice, counter_cache: true
  has_many :agent_oauth_authorizations, dependent: :delete_all
  has_many :agent_oauth_access_tokens, dependent: :delete_all
  has_many :notes, dependent: :delete_all
  has_many :user_consents, dependent: :delete_all

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
  before_save :rotate_session_token, if: :will_save_change_to_password_digest?
  before_destroy :check_if_admin
  after_update :clear_remember_tokens_on_password_change
  after_update :revoke_agent_oauth_credentials, if: :saved_change_to_password_digest?
  after_update_commit :notify_previous_email, if: :saved_change_to_email?

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

  def accepted_current_terms?
    UserConsent.accepted?(self, "terms")
  end

  def accepted_current_privacy?
    UserConsent.accepted?(self, "privacy")
  end

  # Remember token functionality for persistent login. Only a digest is
  # stored, so the database alone can't be used to sign in; the raw token is
  # kept in memory just long enough to write the cookie.
  attr_reader :remember_token

  def self.digest_remember_token(token)
    Digest::SHA256.hexdigest(token)
  end

  def self.find_by_remember_token(token)
    find_by(remember_token_digest: digest_remember_token(token)) if token.present?
  end

  def remember_me!
    @remember_token = SecureRandom.urlsafe_base64(32)
    self.remember_token_digest = self.class.digest_remember_token(remember_token)
    self.remember_token_expires_at = 2.weeks.from_now
    save!(validate: false)
  end

  def forget_me!
    @remember_token = nil
    self.remember_token_digest = nil
    self.remember_token_expires_at = nil
    save!(validate: false)
  end

  def remember_token_valid?
    remember_token_digest.present? && remember_token_expires_at.present? && Time.current < remember_token_expires_at
  end

  # Every signed-in session stores this token; changing the password replaces
  # it, which signs out every other browser that still holds the old one.
  def ensure_session_token!
    update_column(:session_token, SecureRandom.urlsafe_base64(32)) if session_token.blank?
  end

  def session_token_matches?(token)
    # Users who haven't signed in since session tokens were added have none
    # yet; their sessions stay valid until they sign in or change password.
    return true if session_token.blank?

    token.present? && ActiveSupport::SecurityUtils.secure_compare(session_token, token)
  end

  private

  def validate_password?
    password.present? && password_confirmation.present?
  end

  def check_if_admin
    return unless is_admin?

    errors.add(:base, I18n.t('errors.messages.unauthorised'))
    throw(:abort)
  end

  def set_admin_role_for_first_user
    self.roles = 'admin' if User.where('practice_id = ?', practice_id).count.zero?
  end

  def reset_perishable_token
    self.perishable_token = SecureRandom.urlsafe_base64(15)
  end

  def rotate_session_token
    self.session_token = SecureRandom.urlsafe_base64(32)
  end

  def reset_perishable_token!
    update_attribute(:perishable_token, SecureRandom.urlsafe_base64(15))
  end

  def clear_remember_tokens_on_password_change
    return unless saved_change_to_password_digest?

    @remember_token = nil
    self.remember_token_digest = nil
    self.remember_token_expires_at = nil
    update_columns(remember_token_digest: nil, remember_token_expires_at: nil)
  end

  # A new password also disconnects this user's AI apps. The practice is
  # locked first, like every other credential change, so a refresh running
  # at the same moment can't issue a token after this.
  def revoke_agent_oauth_credentials
    practice.with_lock do
      agent_oauth_access_tokens.where(revoked_at: nil).update_all(revoked_at: Time.current)
      agent_oauth_authorizations.where(consumed_at: nil).delete_all
    end
  end

  def notify_previous_email
    NotifierMailer.email_changed(self, email_before_last_save).deliver_now
  end

  def prevent_superadmin_elevation
    return unless roles&.include?('superadmin')

    # Allow if this record is already persisted as superadmin in the DB (fixtures/seeds)
    already_superadmin = id.present? && User.where(id: id, roles: 'superadmin').exists?
    return if already_superadmin

    errors.add(:roles, I18n.t('errors.messages.unauthorised'))
  end
end
