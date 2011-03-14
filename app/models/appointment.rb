class Appointment < ActiveRecord::Base
  belongs_to :practice
  belongs_to :doctor
  belongs_to :patient

  validates_presence_of :practice_id, :doctor_id, :patient_id
end
