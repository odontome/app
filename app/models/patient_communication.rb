class PatientCommunication < ActiveRecord::Base
  # permitted attributes
  attr_accessible :user_id, :subject, :message, :number_of_patients

  # associations
  belongs_to :user

  # validations
  validates_presence_of :subject, :message
end
