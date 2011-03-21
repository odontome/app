class Appointment < ActiveRecord::Base
  # associations
  belongs_to :practice
  belongs_to :doctor
  belongs_to :patient
  
  scope :mine, lambda { 
    where("appointments.practice_id = ? ", UserSession.find.user.practice_id)
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
  
  def self.find_for_calendar(starts_at, ends_at)
    #return self.where("appointments.starts_at > ? AND appointments.ends_at < ? AND appointments.practice_id = ?", starts_at, ends_at, UserSession.find.user.practice_id).includes(:patients).order("starts_at desc").select("id, starts_at AS start, ends_at AS end, notes AS title")
    
    return self.select("id, starts_at AS start, ends_at AS end, notes AS title, doctor_id, practice_id, patient_id").mine
  end
  
end