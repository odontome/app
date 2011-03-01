class User < ActiveRecord::Base
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

  belongs_to :practice
  
end
