class Patient < ActiveRecord::Base
  has_many :appointments, :dependent => :destroy 
  has_many :balances, :dependent => :destroy 
  has_many :patient_notes, :dependent => :destroy 
  has_many :doctors, :through => :appointments
  belongs_to :practice

  scope :mine, lambda { 
    where("patients.practice_id = ? ", UserSession.find.user.practice_id)
  }  
  
  scope :search, lambda { |q|
    select("id,uid,firstname,lastname")
    .where("uid LIKE '%"+q+"%' OR firstname LIKE '%"+q+"%' OR lastname LIKE '%"+q+"%'")
    .mine
    .limit(10)
    .order("firstname")
  }
  
  # validations
  validates_uniqueness_of :uid, :scope => :practice_id, :allow_nil => true, :allow_blank => true
  validates_presence_of :practice_id, :firstname, :lastname, :date_of_birth, :past_illnesses, :allergies,:past_illnesses, :surgeries, :medications, :drugs_use, :family_diseases
  validates_numericality_of :cigarettes_per_day, :drinks_per_day, :only_integer => true, :greater_than_or_equal_to => 0
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
  
  # this functions checks if the user was created from the datebook (skipped all validation, so most of the data is invalid)
  def invalid?
    return date_of_birth.nil?
  end
  
  def self.find_or_create_from(patient_id_or_name)
    # remove any possible commas from this value
    patient_id_or_name.gsub!(",", "")
    
    # Check if we are dealing with an integer or a string
    if (patient_id_or_name.to_i == 0)
      # instantiate a new patient
      patient = Patient.new()
      patient.fullname = patient_id_or_name
      # set the practice_id manually because validation (and callbacks apparently as well) are skipped
      patient.practice_id = UserSession.find.user.practice_id
      # skip validation when saving this patient
      patient.save!(:validate => false)
      # now use the recently created patient id
      patient_id_or_name = patient.id
    end

    return patient_id_or_name
  end

end
