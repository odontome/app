# frozen_string_literal: true

require 'test_helper'

class AppointmentReviewTaskTest < RakeTaskTestCase
  rake_task 'odontome:send_appointment_review_to_patients'

  def setup
    super
    travel_to Time.utc(2025, 1, 1, 9, 0, 0)
    ActionMailer::Base.deliveries.clear
  end

  def teardown
    travel_back
    super
  end

  test 'sends review email for confirmed appointments ended 45min to 3 days ago' do
    appointment = create_appointment(ends_at: 2.hours.ago)

    @task.invoke

    assert_equal 1, ActionMailer::Base.deliveries.count
    assert appointment.reload.notified_of_review
  end

  test 'marks appointments as notified_of_review' do
    appointment = create_appointment(ends_at: 1.day.ago)

    @task.invoke

    assert appointment.reload.notified_of_review
  end

  test 'skips already-notified appointments' do
    appointment = create_appointment(ends_at: 2.hours.ago, notified_of_review: true)

    assert_raises(SystemExit) { @task.invoke }

    assert_empty ActionMailer::Base.deliveries
    assert appointment.reload.notified_of_review
  end

  test 'skips cancelled appointments' do
    appointment = create_appointment(ends_at: 2.hours.ago, status: Appointment.status[:cancelled])

    assert_raises(SystemExit) { @task.invoke }

    assert_empty ActionMailer::Base.deliveries
    refute appointment.reload.notified_of_review
  end

  test 'skips appointments ended less than 45 minutes ago' do
    appointment = create_appointment(ends_at: 30.minutes.ago)

    assert_raises(SystemExit) { @task.invoke }

    assert_empty ActionMailer::Base.deliveries
    refute appointment.reload.notified_of_review
  end

  private

  def create_appointment(starts_at: nil, ends_at: 2.hours.ago,
                         patient: patients(:one),
                         doctor: doctors(:rebecca),
                         datebook: datebooks(:playa_del_carmen),
                         status: Appointment.status[:confirmed],
                         notified_of_review: false)
    starts_at ||= ends_at - 1.hour

    Appointment.create!(
      datebook: datebook,
      doctor: doctor,
      patient: patient,
      starts_at: starts_at,
      ends_at: ends_at,
      status: status,
      notified_of_review: notified_of_review
    )
  end
end
