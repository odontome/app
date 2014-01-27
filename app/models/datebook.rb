class Datebook < ActiveRecord::Base
  # permitted attributes
  attr_accessible :name, :practice_id

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
  before_destroy :check_if_is_deleteable

  def is_deleteable
    return true if self.appointments.count == 0
  end

  private
  
  def check_if_is_deleteable
    unless self.is_deleteable
      self.errors[:base] << I18n.t("errors.messages.has_appointments")
      false
    end
  end

end
