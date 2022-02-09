# frozen_string_literal: true

class Doctor < ApplicationRecord
  # concerns
  include Initials

  # associations
  belongs_to :practice, counter_cache: true
  has_many :appointments
  has_many :patients, through: :appointments

  scope :with_practice, lambda { |practice_id|
    where('doctors.practice_id = ? ', practice_id)
      .order('doctors.firstname')
  }

  scope :valid, lambda {
    where('doctors.is_active = ?', true)
  }

  # validations
  validates_presence_of :practice_id, :firstname, :lastname
  validates_uniqueness_of :uid, scope: :practice_id, allow_nil: true, allow_blank: true
  validates_uniqueness_of :email, scope: :practice_id, allow_nil: true, allow_blank: true
  validates_length_of :uid, within: 0..25, allow_blank: true
  validates_length_of :speciality, within: 0..50, allow_blank: true
  validates :email, format: { with: /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z/i }, allow_nil: true,
                    allow_blank: true

  # callbacks
  before_destroy :check_if_is_deleteable

  def fullname
    [gender === 'female' || gender === 'mujer' ? I18n.t(:female_doctor_prefix) : I18n.t(:male_doctor_prefix), firstname,
     lastname].join(' ')
  end

  def is_deleteable
    return true if appointments.count.zero?
  end

  def ciphered_feed_url
    ciphered_url_encoded_id = Cipher.encode(id.to_s)
    "https://my.odonto.me/doctors/#{ciphered_url_encoded_id}/appointments.ics"
  end

  private

  def check_if_is_deleteable
    unless is_deleteable
      errors[:base] << I18n.t('errors.messages.has_appointments_or_treatments')
      false
    end
  end
end
