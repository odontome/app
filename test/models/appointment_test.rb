# frozen_string_literal: true

require 'test_helper'

class AppointmentTest < ActiveSupport::TestCase
  test 'today_for_practice returns all todays appointments for practice' do
    practice = practices(:complete)
    doctor = doctors(:rebecca)
    datebook = datebooks(:playa_del_carmen)

    patient = Patient.create!(
      practice: practice, firstname: 'Test', lastname: 'Today',
      uid: 'TODAY01', date_of_birth: Date.new(1990, 1, 1)
    )

    # Today's confirmed appointment
    today_confirmed = Appointment.create!(
      datebook: datebook, doctor: doctor, patient: patient,
      starts_at: Time.current.change(hour: 10), ends_at: Time.current.change(hour: 10, min: 30),
      status: Appointment.status[:confirmed]
    )

    # Today's waiting room appointment
    today_waiting = Appointment.create!(
      datebook: datebook, doctor: doctor, patient: patient,
      starts_at: Time.current.change(hour: 11), ends_at: Time.current.change(hour: 11, min: 30),
      status: Appointment.status[:waiting_room]
    )

    # Today's cancelled appointment (should be included)
    today_cancelled = Appointment.create!(
      datebook: datebook, doctor: doctor, patient: patient,
      starts_at: Time.current.change(hour: 14), ends_at: Time.current.change(hour: 14, min: 30),
      status: Appointment.status[:cancelled]
    )

    # Yesterday's confirmed appointment (should be excluded)
    yesterday_confirmed = Appointment.create!(
      datebook: datebook, doctor: doctor, patient: patient,
      starts_at: 1.day.ago.change(hour: 10), ends_at: 1.day.ago.change(hour: 10, min: 30),
      status: Appointment.status[:confirmed]
    )

    results = Appointment.today_for_practice(practice.id, practice.timezone)
    result_ids = results.map(&:id)

    assert_includes result_ids, today_confirmed.id
    assert_includes result_ids, today_waiting.id
    assert_includes result_ids, today_cancelled.id
    refute_includes result_ids, yesterday_confirmed.id
  end
end
