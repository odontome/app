class Appointment < ActiveRecord::Base
	# plugins
	acts_as_audited

  # associations
  belongs_to :practice, :counter_cache => true
  belongs_to :doctor
  belongs_to :patient
  
  scope :mine, lambda { 
    where("appointments.practice_id = ? ", UserSession.find.user.practice_id)
  }
   
  scope :find_between, lambda { |starts_at, ends_at|
    where("appointments.starts_at > ? AND appointments.ends_at < ?", Time.at(starts_at.to_i), Time.at(ends_at.to_i))
    .order("appointments.starts_at")
    .mine
  }
    
  # validations
  validates_presence_of :practice_id, :doctor_id, :patient_id
  validates_numericality_of :practice_id, :doctor_id, :patient_id
  validate :ends_at_should_be_later_than_starts_at
  validates :notes, :length => { :within => 0..255 }, :allow_blank => true
  
  # callbacks
  before_validation :set_practice_id, :on => :create
  before_create :set_ends_at
  
  # Overwrite de JSON response to comply with that the event calendar wants
  def as_json(options = {})
      {
      	:id => id,
        :start => starts_at.to_formatted_s(:rfc822),
        :end => ends_at.to_formatted_s(:rfc822),
        :title => notes,
        :doctor_id => doctor_id,
        :practice_id => practice_id,
        :patient_id => patient_id,
        :color => doctor.color,
        :doctor_name => doctor.fullname,
        :firstname => patient.firstname,
        :lastname => patient.lastname
      }
	end
  
  private
  
  def ends_at_should_be_later_than_starts_at
  	if !self.starts_at.nil? && !self.ends_at.nil?
	  	if self.starts_at >= self.ends_at  
	  		self.errors[:base] << _("Invalid date range")
	  	end
	  end
  end
  
  def set_ends_at
  	if self.ends_at.nil?
    	self.ends_at = self.starts_at + 60.minutes
    end
  end
  


end