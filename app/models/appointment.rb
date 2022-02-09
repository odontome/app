# frozen_string_literal: true

class Appointment < ApplicationRecord
  # associations
  belongs_to :datebook
  belongs_to :doctor
  belongs_to :patient
  has_one :review, dependent: :destroy

  scope :find_between, lambda { |starts_at, ends_at|
    includes(:doctor, :patient)
      .where('appointments.starts_at > ? AND appointments.ends_at < ?', Time.at(starts_at.to_i), Time.at(ends_at.to_i))
      .order('appointments.starts_at')
  }

  scope :find_from_doctor_and_between, lambda { |doctor_id, starts_at, ends_at|
    where('appointments.doctor_id = ?', doctor_id)
      .find_between starts_at, ends_at
  }

  # validations
  validates_presence_of :datebook_id, :doctor_id, :patient_id
  validates_numericality_of :datebook_id, :doctor_id, :patient_id
  validate :ends_at_should_be_later_than_starts_at
  validates :notes, length: { within: 0..255 }, allow_blank: true

  # callbacks
  before_create :set_ends_at

  def is_cancelled
    status == self.class.status[:cancelled]
  end

  def is_confirmed
    status == self.class.status[:confirmed]
  end

  def self.status
    {
      confirmed: 'confirmed',
      cancelled: 'cancelled'
    }
  end

  # Overwrite de JSON response to comply with what the event calendar wants
  # this needs to be overwritten in the "web" version and not the whole app
  def as_json(_options = {})
    {
      id: id,
      start: starts_at.to_formatted_s(:rfc822),
      end: ends_at.to_formatted_s(:rfc822),
      title: notes,
      doctor_id: doctor_id,
      datebook_id: datebook_id,
      patient_id: patient_id,
      color: is_confirmed ? doctor.color : '#cdcdcd',
      doctor_name: doctor.fullname,
      firstname: patient.firstname,
      lastname: patient.lastname
    }
  end

  # find all the appointments of a give patient and arrange them
  # in past and future hashes
  def self.find_all_past_and_future_for_patient(patient_id)
    appointments = Appointment.where('patient_id = ?', patient_id)
      .includes(:doctor)
      .order('starts_at desc')
  end

  def ciphered_url
    encoded_id = ciphered_id

    "https://my.odonto.me/datebooks/#{datebook_id}/appointments/#{encoded_id}"
  end

  def ciphered_review_url
    encoded_appointment_id = ciphered_id

    "https://my.odonto.me/reviews/new/?appointment_id=#{encoded_appointment_id}"
  end

  def ciphered_id
    Cipher.encode(id.to_s)
  end

  private

  def ends_at_should_be_later_than_starts_at
    if !starts_at.nil? && !ends_at.nil? && (starts_at >= ends_at)
      errors.add(:base, I18n.t('errors.messages.invalid_date_range'))
    end
  end

  def set_ends_at
    self.ends_at = starts_at + 60.minutes if ends_at.nil?
  end
end
