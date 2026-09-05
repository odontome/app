# frozen_string_literal: true

require 'test_helper'

class AppointmentTest < ActiveSupport::TestCase
  test 'calendar titles normalize missing notes and preserve entered notes' do
    appointment = appointments(:first_visit)

    [nil, '', 'Review & follow-up'].each do |notes|
      appointment.notes = notes
      [false, true].each do |wall_clock|
        assert_equal notes.to_s, appointment.as_json(wall_clock: wall_clock).fetch(:title)
      end
    end
  end

  [
    ['UTC', Time.utc(2026, 9, 4, 23, 30)],
    ['America/Cancun', Time.utc(2026, 1, 4, 1, 30)]
  ].each do |app_timezone, now|
    test "today_for_practice uses the practice date when #{app_timezone} has a different date" do
      Time.use_zone(app_timezone) do
        travel_to now do
          practice = practices(:complete)
          doctor = doctors(:rebecca)
          datebook = datebooks(:playa_del_carmen)
          practice_now = Time.current.in_time_zone(practice.timezone)
          refute_equal Time.current.to_date, practice_now.to_date

          patient = Patient.create!(
            practice: practice, firstname: 'Test', lastname: 'Today',
            uid: 'TODAY01', date_of_birth: Date.new(1990, 1, 1)
          )

          # Build today's appointments in the practice timezone, not the app timezone.
          today_confirmed = Appointment.create!(
            datebook: datebook, doctor: doctor, patient: patient,
            starts_at: practice_now.change(hour: 10), ends_at: practice_now.change(hour: 10, min: 30),
            status: Appointment.status[:confirmed]
          )

          today_waiting = Appointment.create!(
            datebook: datebook, doctor: doctor, patient: patient,
            starts_at: practice_now.change(hour: 11), ends_at: practice_now.change(hour: 11, min: 30),
            status: Appointment.status[:waiting_room]
          )

          # Cancelled appointments are also included in the daily schedule.
          today_cancelled = Appointment.create!(
            datebook: datebook, doctor: doctor, patient: patient,
            starts_at: practice_now.change(hour: 14), ends_at: practice_now.change(hour: 14, min: 30),
            status: Appointment.status[:cancelled]
          )

          yesterday_confirmed = Appointment.create!(
            datebook: datebook, doctor: doctor, patient: patient,
            starts_at: practice_now.yesterday.change(hour: 10), ends_at: practice_now.yesterday.change(hour: 10, min: 30),
            status: Appointment.status[:confirmed]
          )

          result_ids = Appointment.today_for_practice(practice.id, practice.timezone).map(&:id)

          assert_includes result_ids, today_confirmed.id
          assert_includes result_ids, today_waiting.id
          assert_includes result_ids, today_cancelled.id
          refute_includes result_ids, yesterday_confirmed.id
        end
      end
    end
  end
end
