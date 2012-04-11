class Patient < ActiveRecord::Base  
	# plugins

  # associations
  has_many :appointments, :dependent => :delete_all
  has_many :balances, :dependent => :delete_all 
  has_many :notes, :as => :noteable, :dependent => :delete_all   
  has_many :doctors, :through => :appointments
  has_many :patient_treatments, :dependent => :delete_all
  belongs_to :practice, :counter_cache => true
	
  scope :mine, lambda { 
    where("patients.practice_id = ? ", UserSession.find.user.practice_id)
    .order("firstname")
  }
  
  scope :alphabetically, lambda { |letter|
  	mine
  	.select("firstname,lastname,uid,id,date_of_birth,allergies,email")
  	.where("lower(firstname) LIKE ?", "#{letter.downcase}%")
  }
  
  scope :search, lambda { |q|
    select("id,uid,firstname,lastname")
    .where("uid LIKE '%"+q+"%' OR lower(firstname) LIKE '%"+q.downcase+"%' OR lower(lastname) LIKE '%"+q.downcase+"%'")
    .mine
    .limit(10)
    .order("firstname")
  }  
    
  # validations
  validates_uniqueness_of :uid, :scope => :practice_id, :allow_nil => true, :allow_blank => true
  validates_presence_of :practice_id, :firstname, :lastname, :date_of_birth, :past_illnesses, :surgeries, :medications, :drugs_use, :family_diseases, :emergency_telephone, :cigarettes_per_day, :drinks_per_day
  
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
  before_create :check_for_patients_limit
  after_create :destroy_nils
    
  def fullname
    [firstname, lastname].join(' ')
  end
  
  def fullname=(name)
    split = name.split(' ', 2)
    self.firstname = split.first
    self.lastname = split.last
  end

  def age
    if !self.missing_info?
      (Time.now.year - date_of_birth.year) - (Time.now.yday < date_of_birth.yday ? 1 : 0)
    else
      return 0
    end
  end
  
  # this functions checks if the user was created from the datebook (skipped all validation, so most of the data is invalid)
  def missing_info?
    return date_of_birth.nil?
  end
  
  # this function tries to find a patient by an ID or it's NAME, otherwise it creates one
  def self.find_or_create_from(patient_id_or_name)
    # remove any possible commas from this value
    patient_id_or_name.gsub!(",", "")
      
    # Check if we are dealing with an integer or a string
    if (patient_id_or_name.to_i == 0)
      # instantiate a new patient
      patient = new()
      patient.fullname = patient_id_or_name
      # set the practice_id manually because validation (and callbacks apparently as well) are skipped
      patient.practice_id = UserSession.find.user.practice_id
      # skip validation when saving this patient
      patient.save!(:validate => false)

      patient_id_or_name = patient.id  
    end
    
    # validate that this patient really exists
    begin
    	patient_double_check = Patient.find(patient_id_or_name)
          	
    	rescue ActiveRecord::RecordNotFound
    		patient_id_or_name = nil
    end
    

    return patient_id_or_name
  end
    
  private
  
  def check_for_patients_limit
    unless Practice.find(self.practice.id).number_of_patients > Patient.mine.count
      self.errors[:base] << _("We are very sorry, but you have reached your patients limit. Please upgrade your account in My Practice settings")
      false
    end
  end
  
  # this function is a small compromise to bypass that weird situation where a patient is created with everything set to nil
  def destroy_nils
  	Patient.mine.destroy_all(:firstname => nil)
  end

end
