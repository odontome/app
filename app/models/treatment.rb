class Treatment < ActiveRecord::Base
   
  # associations
  belongs_to :practice
  
  scope :mine, lambda { 
     where("treatments.practice_id = ? ", UserSession.find.user.practice_id)
  }

  # validations
  validates_presence_of :practice_id, :name, :price
  validates_length_of :name, :within => 1..100
  validates_numericality_of :price
  
  # callbacks
  before_validation :set_practice_id, :on => :create
end
