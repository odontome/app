class User < ActiveRecord::Base
  
  belongs_to :practice
  
  acts_as_authentic do |c|
       c.login_field = "email"
       c.validate_email_field = false
  end

  scope :mine, lambda { 
    where("users.practice_id = ? ", UserSession.find.user.practice_id)
  }  

  validates_presence_of :firstname, :lastname, :password, :email, :roles
  validates_uniqueness_of :email
  validates_format_of :email, :with => Authlogic::Regex.email
  validates_confirmation_of :password, :on => :create
  
  # callbacks
  before_validation :set_practice_id, :on => :create
  before_create :set_admin_role_for_first_user
  before_destroy :check_if_admin

  def fullname
    [firstname, lastname].join(' ')
  end

  def preferred_language
    return Practice.find(self.practice_id).locale
  end
  
  private
  def check_if_admin
    if self.roles.include?("admin")
      self.errors[:base] << _("Can't delete admin user")
      false
    end
  end  
  
  def set_admin_role_for_first_user
    self.roles = "admin" if User.where("practice_id = ?", self.practice_id).count == 0
  end
  
end
