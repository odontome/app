class User < ActiveRecord::Base
  
  belongs_to :practice
  
  acts_as_authentic do |c|
       c.login_field = "email"
       c.validate_email_field = false
  end

  scope :mine, lambda { 
    where("users.practice_id = ? ", UserSession.find.user.practice_id)
  }  

  validates :firstname, :presence => true
  validates :lastname, :presence => true
  validates :email, :presence => true, :uniqueness => true
  validates_format_of :email, :with => Authlogic::Regex.email
  validates_confirmation_of :password, :on => :create
  validates_presence_of :password_confirmation, :on => :create
  validates :password, :presence => true

  before_validation(:on => :create) do
    set_practice_id
  end

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
