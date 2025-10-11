# frozen_string_literal: true

require 'test_helper'

class SixMonthReminderTaskTest < RakeTaskTestCase
  rake_task 'odontome:send_six_month_checkup_reminders'

  def setup
    super
    ActionMailer::Base.deliveries.clear

    # Mock time to 10 AM UTC to ensure timezone filtering works
    @mocked_time = Time.parse('2025-08-19 10:00:00 UTC')
    travel_to @mocked_time

    # Choose a timezone where local time is 10 to satisfy the task filter
    @zone_for_10 = ActiveSupport::TimeZone.all.find { |z| Time.now.in_time_zone(z).hour == 10 }&.name
    # Fallback to UTC if none found
    @zone_for_10 ||= 'UTC'
  end

  def teardown
    super
    travel_back
  end

  test 'sends reminder for trialing/active practice and marks patient as notified' do
    practice = practices(:complete) # has trialing subscription via fixtures
    practice.update_columns(timezone: @zone_for_10, cancelled_at: nil)

    patient = patients(:one)
    doctor = doctors(:rebecca)
    datebook = datebooks(:playa_del_carmen)

    # Ensure patient belongs to the same practice/datebook associations
    assert_equal practice.id, patient.practice_id
    assert_equal practice.id, datebook.practice_id
    assert_equal practice.id, doctor.practice_id

    # Create a confirmed appointment older than 6 months but not older than 7 months
    # Use the current (mocked) time for consistent calculation
    six_months_ago_from_now = 6.months.ago
    Appointment.create!(
      datebook_id: datebook.id,
      doctor_id: doctor.id,
      patient_id: patient.id,
      starts_at: (six_months_ago_from_now - 1.day),
      ends_at: (six_months_ago_from_now - 1.day) + 1.hour,
      status: Appointment.status[:confirmed]
    )

    # Sanity: patient not notified yet
    assert_equal false, patient.reload.notified_of_six_month_reminder

    @task.invoke

    # Ensure our target patient received an email and flag was set
    recipients = ActionMailer::Base.deliveries.map { |m| m.to }.flatten
    assert_includes recipients, patient.email
    assert_equal true, patient.reload.notified_of_six_month_reminder
  end

  test 'skips reminder for past_due and canceled practices' do
    # past_due practice setup
    past_due_practice = practices(:past_due_practice)
    past_due_practice.update_columns(timezone: @zone_for_10, cancelled_at: nil)

    past_due_patient = Patient.create!(
      practice_id: past_due_practice.id,
      firstname: 'Past', lastname: 'Due', email: 'pastdue@example.com',
      date_of_birth: Date.new(1990, 1, 1)
    )
    past_due_doctor = Doctor.create!(
      practice_id: past_due_practice.id,
      firstname: 'Doc', lastname: 'PD', email: 'docpd@example.com', uid: 'PD1'
    )
    past_due_datebook = Datebook.create!(practice_id: past_due_practice.id, name: 'PD')
    Appointment.create!(
      datebook_id: past_due_datebook.id,
      doctor_id: past_due_doctor.id,
      patient_id: past_due_patient.id,
      starts_at: (6.months.ago - 1.day),
      ends_at: (6.months.ago - 1.day) + 1.hour,
      status: Appointment.status[:confirmed]
    )

    # canceled practice setup (explicitly mark cancelled_at)
    canceled_practice = practices(:canceled_practice)
    canceled_practice.update_columns(timezone: @zone_for_10, cancelled_at: Time.now)

    canceled_patient = Patient.create!(
      practice_id: canceled_practice.id,
      firstname: 'Canceled', lastname: 'Pat', email: 'canceled@example.com',
      date_of_birth: Date.new(1990, 2, 2)
    )
    canceled_doctor = Doctor.create!(
      practice_id: canceled_practice.id,
      firstname: 'Doc', lastname: 'C', email: 'docc@example.com', uid: 'C1'
    )
    canceled_datebook = Datebook.create!(practice_id: canceled_practice.id, name: 'C')
    Appointment.create!(
      datebook_id: canceled_datebook.id,
      doctor_id: canceled_doctor.id,
      patient_id: canceled_patient.id,
      starts_at: (6.months.ago - 1.day),
      ends_at: (6.months.ago - 1.day) + 1.hour,
      status: Appointment.status[:confirmed]
    )

    # Invoke task and ensure no emails are sent for these practices
    @task.reenable
    @task.invoke

    assert_equal 0, ActionMailer::Base.deliveries.size
    assert_equal false, past_due_patient.reload.notified_of_six_month_reminder
    assert_equal false, canceled_patient.reload.notified_of_six_month_reminder
  end

  test 'skips reminder when last visit is older than 7 months' do
    ActionMailer::Base.deliveries.clear

    practice = practices(:complete)
    # Ensure timezone matches sending hour filter
    zone_for_10 = ActiveSupport::TimeZone.all.find { |z| Time.now.in_time_zone(z).hour == 10 }&.name || Time.zone.name
    practice.update_columns(timezone: zone_for_10, cancelled_at: nil)

    patient = patients(:one)
    doctor = doctors(:rebecca)
    datebook = datebooks(:playa_del_carmen)

    # Create a confirmed appointment strictly older than 7 months
    Appointment.create!(
      datebook_id: datebook.id,
      doctor_id: doctor.id,
      patient_id: patient.id,
      starts_at: 8.months.ago,
      ends_at: 8.months.ago + 1.hour,
      status: Appointment.status[:confirmed]
    )

    refute patient.reload.notified_of_six_month_reminder

    @task.reenable
    @task.invoke

    # No email sent and flag remains false because outside 6–7 month window
    recipients = ActionMailer::Base.deliveries.map { |m| m.to }.flatten
    refute_includes recipients, patient.email
    assert_equal false, patient.reload.notified_of_six_month_reminder
  end
end
