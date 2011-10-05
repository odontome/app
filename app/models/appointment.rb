class Appointment < ActiveRecord::Base
  # associations
  belongs_to :practice, :counter_cache => true
  belongs_to :doctor
  belongs_to :patient
  
  scope :mine, lambda { 
    where("appointments.practice_id = ? ", UserSession.find.user.practice_id)
  }
  
  scope :find_between, lambda { |starts_at, ends_at|
    select("appointments.id, appointments.starts_at AS start, appointments.ends_at AS end, appointments.notes AS title, appointments.doctor_id, appointments.practice_id, appointments.patient_id, doctors.color, patients.firstname, patients.lastname")
    .joins("LEFT OUTER JOIN patients ON patients.id = appointments.patient_id")
    .joins("LEFT OUTER JOIN doctors ON doctors.id = appointments.doctor_id")
    .where("appointments.starts_at > ? AND appointments.ends_at < ?", Time.at(starts_at.to_i), Time.at(ends_at.to_i))
    .order("appointments.starts_at")
    .mine
  }
    
  # validations
  validates_presence_of :practice_id, :doctor_id, :patient_id
  validates_numericality_of :practice_id, :doctor_id, :patient_id
  validate :ends_at_should_be_later_than_starts_at
  
  # callbacks
  before_validation :set_practice_id, :on => :create
  before_save :fix_dates
  before_create :set_ends_at
  
  private
  
  def fix_dates 
    # only when the date was modified (not the case when editing the info)
    if self.changes[:starts_at] != nil
      self.starts_at = self.starts_at + (self.starts_at.gmt_offset).seconds
      if self.ends_at != nil  
        self.ends_at = self.ends_at + (self.ends_at.gmt_offset).seconds
      end
    end
  end
  
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