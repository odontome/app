class PatientNote < ActiveRecord::Base
  belongs_to :patient
  
  validates_presence_of :notes
  validates_length_of :notes, :in => 3..500
end
