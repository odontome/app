class Patient < ActiveRecord::Base
  has_many :appointments
  has_many :balances
  has_many :patient_notes
  has_many :doctors, :through => :appointments
  belongs_to :practice

  scope :mine, lambda { 
    where("patients.practice_id = ? ", UserSession.find.user.practice_id)
  }  
  
  # validations
  validates_uniqueness_of :uid, :scope => :practice_id, :allow_nil => true, :allow_blank => true
  validates_presence_of :practice_id, :firstname, :lastname, :date_of_birth
  validates_length_of :uid, :within => 0..25, :allow_blank => true
  validates_length_of :firstname, :within => 1..25
  validates_length_of :lastname, :within => 1..25
  validates_length_of :address, :within => 0..100, :allow_blank => true
  validates_length_of :telephone, :within => 0..20, :allow_blank => true
  validates_length_of :mobile, :within => 0..20, :allow_blank => true
  validates_length_of :emergency_telephone, :within => 5..20
  validates_format_of :email, :with => Authlogic::Regex.email, :allow_blank => true
  
  # callbacks
  before_validation :set_practice_id, :on => :create

  def fullname
    [firstname, lastname].join(' ')
  end
  
  def fullname=(name)
    split = name.split(' ', 2)
    self.firstname = split.first
    self.lastname = split.last
  end

  def age
    if !self.invalid?
      (Time.now.year - date_of_birth.year) - (Time.now.yday < date_of_birth.yday ? 1 : 0)
    else
      return 0
    end
  end
  
  def setup_chart
    chart = Chart.create!(:user_id => self.id)
  end
  
  # this functions checks if the user was created from the datebook (skipped all validation, so most of the data is invalid)
  def invalid?
    return date_of_birth.nil?
  end

end
