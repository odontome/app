class Appointment < ActiveRecord::Base
  # associations
  belongs_to :practice
  belongs_to :doctor
  belongs_to :patient
  
  # validations
  validates_presence_of :practice_id, :doctor_id, :patient_id
  
  # callbacks
  before_validation(:on => :create) do
    set_practice_id
  end
end
