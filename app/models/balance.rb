class Balance < ActiveRecord::Base
  # plugins
  
  # associations
  belongs_to :patient
  
  # validations
  validates_presence_of :amount
  validates_numericality_of :amount  
end
