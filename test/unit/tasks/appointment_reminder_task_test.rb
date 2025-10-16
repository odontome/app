# frozen_string_literal: true

require 'test_helper'

class AppointmentReminderTaskTest < RakeTaskTestCase
  rake_task 'odontome:send_appointment_reminder_notifications'

  def setup
    super
    travel_to Time.utc(2025, 1, 1, 9, 0, 0)
    ActionMailer::Base.deliveries.clear
  end

  def teardown
    travel_back
    super
  end

  test 'sends reminder for upcoming confirmed appointments' do
    appointment = create_appointment(starts_at: 24.hours.from_now, ends_at: 25.hours.from_now)

    assert_difference -> { ActionMailer::Base.deliveries.count }, 1 do
      @task.invoke
    end

    assert appointment.reload.notified_of_reminder
  end

  test 'skips appointments with blank patient email' do
    patient = Patient.create!(
      practice: practices(:complete),
      firstname: 'Blank',
      lastname: 'Email',
      email: '',
      date_of_birth: Date.new(1990, 1, 1)
    )
    appointment = create_appointment(patient: patient)

    @task.invoke

    assert_empty ActionMailer::Base.deliveries
    refute appointment.reload.notified_of_reminder
  end

  test 'skips appointments already notified' do
    appointment = create_appointment(notified_of_reminder: true)

    @task.invoke

    assert_empty ActionMailer::Base.deliveries
    assert appointment.reload.notified_of_reminder
  end

  test 'skips appointments outside the 48 hour window' do
    appointment = create_appointment(starts_at: 72.hours.from_now, ends_at: 73.hours.from_now)

    @task.invoke

    assert_empty ActionMailer::Base.deliveries
    refute appointment.reload.notified_of_reminder
  end

  test 'skips appointments that are not confirmed' do
    appointment = create_appointment(status: Appointment.status[:cancelled])

    @task.invoke

    assert_empty ActionMailer::Base.deliveries
    refute appointment.reload.notified_of_reminder
  end

  private

  def create_appointment(starts_at: 24.hours.from_now, ends_at: 25.hours.from_now,
                         patient: patients(:one), doctor: doctors(:rebecca),
                         datebook: datebooks(:playa_del_carmen),
                         status: Appointment.status[:confirmed],
                         notified_of_reminder: false)
    Appointment.create!(
      datebook: datebook,
      doctor: doctor,
      patient: patient,
      starts_at: starts_at,
      ends_at: ends_at,
      status: status,
      notified_of_reminder: notified_of_reminder
    )
  end
end
