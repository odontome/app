# frozen_string_literal: true

class User < ApplicationRecord
  # concerns
  include Initials

  # associations
  belongs_to :practice, counter_cache: true
  has_many :notes, dependent: :delete_all

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

  # callbacks
  before_create :set_admin_role_for_first_user
  before_update :reset_perishable_token
  before_destroy :check_if_admin

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

  private

  def validate_password?
    password.present? && password_confirmation.present?
  end

  def check_if_admin
    if is_admin?
      errors[:base] << I18n.t('errors.messages.unauthorised')
      false
    end
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
end
