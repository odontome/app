class User < ActiveRecord::Base
  
  belongs_to :practice, :counter_cache => true
  
  acts_as_authentic do |c|
    c.login_field = "email"
    c.validate_email_field = false
  end

  scope :mine, lambda { 
    where("users.practice_id = ? ", UserSession.find.user.practice_id)
  }  

  validates_presence_of :firstname, :lastname, :email, :roles
  validates_uniqueness_of :email
  validates_format_of :email, :with => Authlogic::Regex.email
  validates :firstname, :lastname, :length => { :maximum => 20 }
  validates :password, :length => { :minimum => 7 }, :if => :validate_password?
  validates :password_confirmation, :length => { :minimum => 7 }, :if => :validate_password?
  
  # callbacks
  before_validation :set_practice_id, :on => :create
  before_create :set_admin_role_for_first_user
  before_destroy :check_if_admin
  before_update :check_if_is_editeable_by_non_admins
  before_save :update_authentication_token

  def fullname
    [firstname, lastname].join(' ')
  end

  def preferred_language
    return Practice.find(self.practice_id).locale
  end

  def deliver_password_reset_instructions!
    reset_perishable_token!
    NotifierMailer.deliver_password_reset_instructions(self).deliver
  end
    
  private

  def validate_password?
    self.password.present? && self.password_confirmation.present?
  end
  
  def check_if_admin
    if self.roles.include?("admin")
      self.errors[:base] << I18n.t("errors.messages.unauthorised")
      false
    end
  end  
  
  def set_admin_role_for_first_user
    self.roles = "admin" if User.where("practice_id = ?", self.practice_id).count == 0
  end

  def check_if_is_editeable_by_non_admins # normal users can't edit admins
    if UserSession.find && self.roles.include?("admin") && !UserSession.find.user.roles.include?("admin")
      self.errors[:base] << I18n.t("errors.messages.unauthorised")
      false 
    end
  end
  
  def update_authentication_token
  	if self.crypted_password_changed?
  		begin
        self.authentication_token = SecureRandom.hex
      end while self.class.exists?(authentication_token: authentication_token)
  	end
  end
  
end
