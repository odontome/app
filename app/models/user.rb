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
  validates_presence_of :password, :on => :create
  validates_confirmation_of :password, :on => :create
  
  validates :firstname, :lastname, :length => { :maximum => 20 }
  validates :password, :length => { :minimum => 4 }
  
  # callbacks
  before_validation :set_practice_id, :on => :create
  before_create :set_admin_role_for_first_user
  before_destroy :check_if_admin
  before_update :check_if_is_editeable_by_non_admins
  before_save :ensure_authentication_token

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
  
  def check_if_admin
    if self.roles.include?("admin")
      self.errors[:base] << _("Can't delete an admin user")
      false
    end
  end  
  
  def set_admin_role_for_first_user
    self.roles = "admin" if User.where("practice_id = ?", self.practice_id).count == 0
  end

  def check_if_is_editeable_by_non_admins #normal users can't edit admins
    if UserSession.find && self.roles.include?("admin") && !UserSession.find.user.roles.include?("admin")
      self.errors[:base] << _("Sorry, you can't update an admin user")
      false 
    end
  end
  
  def ensure_authentication_token
  	if !self.login_count_changed?
  		self.authentication_token = Authlogic::Random.hex_token
  	end
  end
  
end
