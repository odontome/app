class Appointment < ActiveRecord::Base
  # associations
  belongs_to :practice
  belongs_to :doctor
  belongs_to :patient
  
  # callbacks
  before_validation(:on => :create) do
    set_practice_id
  end
end
