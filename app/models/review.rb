class Review < ActiveRecord::Base

  # associations
  has_many :appointments

  # validations
  validates_presence_of :score
  validates_numericality_of :score, :appointment_id
  validates_uniqueness_of :appointment_id
  validates :comment, :length => { :within => 0..255 }

end
