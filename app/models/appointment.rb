class Appointment < ActiveRecord::Base
  # associations
  belongs_to :practice
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
    .mine
  }
    
  # validations
  validates_presence_of :practice_id, :doctor_id, :patient_id
  validates_numericality_of :practice_id, :doctor_id, :patient_id
  
  # callbacks
  before_validation :set_practice_id, :on => :create
  before_create :set_ends_at
  
  private
  
  def set_ends_at
     self.ends_at = self.starts_at + 60.minutes
  end

end