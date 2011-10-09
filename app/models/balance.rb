class Balance < ActiveRecord::Base
  # plugins
  acts_as_audited
  
  # associations
  belongs_to :patient
  
  # validations
  validates_presence_of :amount
  validates_numericality_of :amount  
end
