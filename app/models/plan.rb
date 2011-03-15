class Plan < ActiveRecord::Base
  has_many :practices
  validates_presence_of :number_of_patients
end
