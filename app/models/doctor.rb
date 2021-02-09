class Doctor < ApplicationRecord
  # permitted attributes
  attr_accessible :uid, :firstname, :lastname, :email, :gender, :speciality, :color, :practice_id

  # associations
  belongs_to :practice, :counter_cache => true
  has_many :appointments
  has_many :patients, :through => :appointments

  scope :with_practice, ->(practice_id) {
    where("doctors.practice_id = ? ", practice_id)
    .order("doctors.firstname")
  }

  scope :valid, lambda {
    where("doctors.is_active = ?", true)
  }

  # validations
  validates_presence_of :practice_id, :firstname, :lastname
  validates_uniqueness_of :uid, :scope => :practice_id, :allow_nil => true, :allow_blank => true
  validates_uniqueness_of :email, :scope => :practice_id, :allow_nil => true, :allow_blank => true
  validates_length_of :uid, :within => 0..25, :allow_blank => true
  validates_length_of :speciality, :within => 0..50, :allow_blank => true
  validates :email, format: { with: /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z/i }

  # callbacks
  before_destroy :check_if_is_deleteable

  def fullname
    [(self.gender === "female") ? I18n.t(:female_doctor_prefix) : I18n.t(:male_doctor_prefix), firstname, lastname].join(' ')
  end

  def is_deleteable
    return true if self.appointments.count == 0
  end

  def ciphered_feed_url
    ciphered_url_encoded_id = Cipher.encode(self.id.to_s)

    return "https://my.odonto.me/doctors/#{ciphered_url_encoded_id}/appointments.ics"
  end

  private

  def check_if_is_deleteable
    unless self.is_deleteable
      self.errors[:base] << I18n.t("errors.messages.has_appointments_or_treatments")
      false
    end
  end

end
