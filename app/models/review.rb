class Review < ApplicationRecord
  # permitted attributes
  attr_accessible :appointment_id, :score, :comment

  # associations
  belongs_to :appointment

  scope :with_practice, ->(practice_id) {
    includes(:appointment => [:doctor, :patient])
    .joins(:appointment => [:datebook => [:practice]])
    .where("practices.id = ? ", practice_id)
    .order(created_at: :desc)
  }

  # validations
  validates_presence_of :score
  validates_numericality_of :score, :appointment_id
  validates_uniqueness_of :appointment_id
  validates :comment, :length => { :within => 0..255 }

end
