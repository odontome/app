class Treatment < ActiveRecord::Base
  # plugins
  
  # associations
  belongs_to :practice
  
  scope :mine, lambda { 
     where("treatments.practice_id = ? ", UserSession.find.user.practice_id)
     .order("name")
  }
  
  scope :valid, lambda {
   	where("price IS NOT NULL")
   	.where("price != 0")
  }

  # validations
  validates_presence_of :practice_id, :name, :price
  validates_length_of :name, :within => 1..100
  validates_numericality_of :price, :greater_than => 0
  
  # callbacks
  before_validation :set_practice_id, :on => :create
  
  def missing_info?
    return price.nil? || price == 0
  end
end
