class Datebook < ActiveRecord::Base

  # associations
  has_many :appointments
  belongs_to :practice, :counter_cache => true

  scope :mine, lambda { 
    where("datebooks.practice_id = ? ", UserSession.find.user.practice_id)
  }

  # validations
  validates_presence_of :practice_id, :name
  validates_numericality_of :practice_id
  validates :name, :length => { :within => 0..100 }

  # callbacks
  before_validation :set_practice_id, :on => :create

end
