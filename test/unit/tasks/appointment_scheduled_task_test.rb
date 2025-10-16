# frozen_string_literal: true

require 'test_helper'

class AppointmentScheduledTaskTest < RakeTaskTestCase
  rake_task 'odontome:send_appointment_scheduled_notifications'

  def setup
    super
    travel_to Time.utc(2025, 1, 1, 9, 0, 0)
    ActionMailer::Base.deliveries.clear
  end

  def teardown
    travel_back
    super
  end

  test 'sends scheduled email for confirmed appointments created more than five minutes ago' do
    appointment = create_appointment(created_at: 10.minutes.ago)

    assert_difference -> { ActionMailer::Base.deliveries.count }, 1 do
      @task.invoke
    end

    assert appointment.reload.notified_of_schedule
  end

  test 'skips appointments created less than five minutes ago' do
    appointment = create_appointment(created_at: 2.minutes.ago)

    @task.invoke

    assert_empty ActionMailer::Base.deliveries
    refute appointment.reload.notified_of_schedule
  end

  test 'skips appointments already notified of schedule' do
    appointment = create_appointment(created_at: 10.minutes.ago, notified_of_schedule: true)

    @task.invoke

    assert_empty ActionMailer::Base.deliveries
    assert appointment.reload.notified_of_schedule
  end

  test 'skips appointments that are not confirmed' do
    appointment = create_appointment(created_at: 10.minutes.ago, status: Appointment.status[:cancelled])

    @task.invoke

    assert_empty ActionMailer::Base.deliveries
    refute appointment.reload.notified_of_schedule
  end

  test 'skips appointments when patient email is blank' do
    patient = Patient.create!(
      practice: practices(:complete),
      firstname: 'Schedule',
      lastname: 'NoEmail',
      email: '',
      date_of_birth: Date.new(1990, 1, 1)
    )
    appointment = create_appointment(created_at: 10.minutes.ago, patient: patient)

    @task.invoke

    assert_empty ActionMailer::Base.deliveries
    refute appointment.reload.notified_of_schedule
  end

  private

  def create_appointment(starts_at: 1.day.from_now, ends_at: 1.day.from_now + 1.hour,
                         created_at: 10.minutes.ago,
                         patient: patients(:one),
                         doctor: doctors(:rebecca),
                         datebook: datebooks(:playa_del_carmen),
                         status: Appointment.status[:confirmed],
                         notified_of_schedule: false)
    appointment = Appointment.create!(
      datebook: datebook,
      doctor: doctor,
      patient: patient,
      starts_at: starts_at,
      ends_at: ends_at,
      status: status,
      notified_of_schedule: notified_of_schedule
    )

    appointment.update_columns(created_at: created_at) if created_at

    appointment
  end
end
