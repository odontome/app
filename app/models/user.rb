class User < ApplicationRecord
  # permitted attributes
  attr_accessible :firstname, :lastname, :email, :password, :password_confirmation

  # associations
  belongs_to :practice, :counter_cache => true
  has_many :notes, :dependent => :delete_all
  has_many :broadcasts, :dependent => :delete_all

  has_secure_password

  # named scopes
  scope :with_practice, ->(practice_id) {
    where("users.practice_id = ? ", practice_id)
  }

  # validations
  validates_presence_of :firstname, :lastname, :email, :roles
  validates_uniqueness_of :email
  validates :email, format: { with: /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z/i }
  validates :firstname, :lastname, :length => { :maximum => 20 }
  validates :password, :length => { :minimum => 7 }, :if => :validate_password?
  validates :password_confirmation, :length => { :minimum => 7 }, :if => :validate_password?

  # callbacks
  before_create :set_admin_role_for_first_user
  before_destroy :check_if_admin
  before_save :update_authentication_token

  def fullname
    [firstname, lastname].join(' ')
  end

  def preferred_language
    return Practice.find(self.practice_id).locale
  end

  def deliver_password_reset_instructions!
    reset_perishable_token!
    NotifierMailer.deliver_password_reset_instructions(self).deliver_now
  end

  def ciphered_unsubscribe_url
    ciphered_url_encoded_id = Cipher.encode(self.id.to_s)

    return "https://my.odonto.me/users/#{ciphered_url_encoded_id}/unsubscribe"
  end

  def is_admin?
    self.roles.include?("admin")
  end

  private

  def validate_password?
    self.password.present? && self.password_confirmation.present?
  end

  def check_if_admin
    if self.is_admin?
      self.errors[:base] << I18n.t("errors.messages.unauthorised")
      false
    end
  end

  def set_admin_role_for_first_user
    self.roles = "admin" if User.where("practice_id = ?", self.practice_id).count == 0
  end

  def update_authentication_token
  	if self.crypted_password_changed?
  		begin
        self.authentication_token = SecureRandom.hex
      end while self.class.exists?(authentication_token: authentication_token)
  	end
  end

  def reset_perishable_token!
    self.update_attribute(:perishable_token, SecureRandom.urlsafe_base64(15))
  end

end
