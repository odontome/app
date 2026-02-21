# frozen_string_literal: true

class Appointment < ApplicationRecord
  # PaperTrail for audit logging
  has_paper_trail meta: { practice_id: ->(appointment) { appointment.datebook.practice_id } }

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
  after_commit :reset_six_month_reminder_flag_if_confirmed, on: %i[create update]

  def is_cancelled
    status == self.class.status[:cancelled]
  end

  def is_confirmed
    status == self.class.status[:confirmed] || status == self.class.status[:waiting_room]
  end

  def is_waiting_room
    status == self.class.status[:waiting_room]
  end

  def is_today
    starts_at.in_time_zone.to_date == Time.zone.today
  end

  def self.status
    {
      confirmed: 'confirmed',
      cancelled: 'cancelled',
      waiting_room: 'confirmed_and_waiting'
    }
  end

  # Overwrite de JSON response to comply with what the event calendar wants
  # this needs to be overwritten in the "web" version and not the whole app
  def as_json(options = {})
    return agent_as_json if options[:agent]

    bg_color = is_confirmed ? doctor.color : '#cdcdcd'
    border_color = doctor.color
    text_color = is_confirmed ? '#ffffff' : '#333333'
    is_waiting_today = (status == self.class.status[:waiting_room]) && (starts_at.in_time_zone.to_date == Time.zone.today)

    {
      id: id,
      start: starts_at.to_formatted_s(:rfc822),
      end: ends_at.to_formatted_s(:rfc822),
      title: notes,
      doctor_id: doctor_id,
      datebook_id: datebook_id,
      patient_id: patient_id,
      color: bg_color,
      backgroundColor: bg_color,
      borderColor: border_color,
      textColor: text_color,
      className: (is_waiting_today ? 'appointment-waiting' : nil),
      doctor_name: doctor.fullname,
      firstname: patient.firstname,
      lastname: patient.lastname,
      patient_uid: patient.uid
    }
  end

  def agent_as_json
    {
      id: id,
      start: starts_at.to_formatted_s(:rfc822),
      end: ends_at.to_formatted_s(:rfc822),
      doctor_id: doctor_id,
      doctor_name: doctor.fullname,
      datebook_id: datebook_id,
      datebook_name: datebook.name,
      status: status,
      notes: notes
    }
  end

  # find all the appointments of a give patient and arrange them
  # in past and future hashes
  def self.find_all_past_and_future_for_patient(patient_id)
    Appointment.where('patient_id = ?', patient_id)
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

  def self.ciphered_review_url_for_id(appointment_id)
    encoded_appointment_id = Cipher.encode(appointment_id.to_s)
    "https://my.odonto.me/reviews/new/?appointment_id=#{encoded_appointment_id}"
  end

  private

  def ends_at_should_be_later_than_starts_at
    return unless !starts_at.nil? && !ends_at.nil? && (starts_at >= ends_at)

    errors.add(:base, I18n.t('errors.messages.invalid_date_range'))
  end

  def set_ends_at
    self.ends_at = starts_at + 60.minutes if ends_at.nil?
  end

  # Reset the one-time six-month reminder flag once a new confirmed appointment exists
  def reset_six_month_reminder_flag_if_confirmed
    return unless status == self.class.status[:confirmed]
    # Be defensive in case associations change in the future
    return if patient.nil?

    # Mark as not-notified so the next six-month cycle can email again
    # Use update_column to avoid triggering validations/callbacks on Patient
    begin
      patient.update_column(:notified_of_six_month_reminder, false)
    rescue StandardError
      # no-op: failing to reset the flag should not affect the appointment lifecycle
    end
  end
end
