class Balance < ActiveRecord::Base
  belongs_to :patient
  
  validates_presence_of :amount
  validates_numericality_of :amount  
end
