class PatientTreatment < ActiveRecord::Base
   
  # associations
  belongs_to :patient
  belongs_to :doctor
  
  # validations
  validates_presence_of :patient_id, :doctor_id, :name, :tooth_number, :price
  validates_length_of :name, :within => 1..100
  validates_numericality_of :price
  validates_numericality_of :tooth_number, :only_integer => true
  
  # constants
  TEETH = [ [11, 11],
            [12, 12],
            [_('N/A'), 0] ]

end
