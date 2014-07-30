class Datebook < ActiveRecord::Base
  # permitted attributes
  attr_accessible :name, :starts_at, :ends_at

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
  validates_numericality_of :starts_at, greater_than: 0
  validates_numericality_of :starts_at, less_than_or_equal_to: 22
  validates_numericality_of :ends_at, greater_than: :starts_at
  validates_numericality_of :ends_at, less_than_or_equal_to: 23

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
