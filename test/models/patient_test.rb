# frozen_string_literal: true

require 'test_helper'

class PatientTest < ActiveSupport::TestCase
  test 'without_upcoming_appointment excludes patients with future non-cancelled appointments' do
    practice = practices(:complete)
    doctor = doctors(:rebecca)
    datebook = datebooks(:playa_del_carmen)

    overdue = Patient.create!(practice: practice, firstname: 'Overdue', lastname: 'Test', uid: 'OVD01', date_of_birth: Date.new(1990, 1, 1))
    scheduled = Patient.create!(practice: practice, firstname: 'Scheduled', lastname: 'Test', uid: 'SCH01', date_of_birth: Date.new(1990, 1, 1))
    cancelled_only = Patient.create!(practice: practice, firstname: 'Cancelled', lastname: 'Only', uid: 'CAN01', date_of_birth: Date.new(1990, 1, 1))

    Appointment.create!(datebook: datebook, doctor: doctor, patient: scheduled,
                         starts_at: 1.week.from_now, ends_at: 1.week.from_now + 30.minutes,
                         status: Appointment.status[:confirmed])

    Appointment.create!(datebook: datebook, doctor: doctor, patient: cancelled_only,
                         starts_at: 1.week.from_now, ends_at: 1.week.from_now + 30.minutes,
                         status: Appointment.status[:cancelled])

    results = Patient.with_practice(practice.id).without_upcoming_appointment
    result_ids = results.pluck(:id)

    assert_includes result_ids, overdue.id
    refute_includes result_ids, scheduled.id
    assert_includes result_ids, cancelled_only.id
  end

  test 'birthday_this_week returns patients with birthdays in the next 7 days' do
    practice = practices(:complete)

    this_week = Patient.create!(practice: practice, firstname: 'Birthday', lastname: 'ThisWeek',
                                 uid: 'BW01', date_of_birth: Date.new(1990, Date.current.month, Date.current.day))

    next_month = Patient.create!(practice: practice, firstname: 'Birthday', lastname: 'NextMonth',
                                  uid: 'BW02', date_of_birth: Date.new(1990, (Date.current + 2.months).month, 15))

    results = Patient.with_practice(practice.id).birthday_this_week(practice.timezone)
    result_ids = results.pluck(:id)

    assert_includes result_ids, this_week.id
    refute_includes result_ids, next_month.id
  end

  test 'birthday_this_week handles month boundary' do
    practice = practices(:complete)

    # Freeze to the last day of a month to test the cross-month branch
    travel_to Time.zone.parse('2026-03-29 12:00:00') do
      march_30 = Patient.create!(practice: practice, firstname: 'March', lastname: 'Thirty',
                                   uid: 'MB01', date_of_birth: Date.new(1985, 3, 30))

      april_2 = Patient.create!(practice: practice, firstname: 'April', lastname: 'Two',
                                  uid: 'MB02', date_of_birth: Date.new(1992, 4, 2))

      april_10 = Patient.create!(practice: practice, firstname: 'April', lastname: 'Ten',
                                   uid: 'MB03', date_of_birth: Date.new(1988, 4, 10))

      results = Patient.with_practice(practice.id).birthday_this_week(practice.timezone)
      result_ids = results.pluck(:id)

      assert_includes result_ids, march_30.id
      assert_includes result_ids, april_2.id
      refute_includes result_ids, april_10.id
    end
  end

  test 'new_this_week returns patients created in current calendar week' do
    practice = practices(:complete)

    this_week = Patient.create!(practice: practice, firstname: 'New', lastname: 'ThisWeek',
                                 uid: 'NW01', date_of_birth: Date.new(1990, 1, 1))

    results = Patient.with_practice(practice.id).new_this_week(practice.timezone)
    result_ids = results.pluck(:id)

    assert_includes result_ids, this_week.id
  end

  test 'needs_follow_up returns patients with no recent visit and no future appointment' do
    practice = practices(:complete)
    doctor = doctors(:rebecca)
    datebook = datebooks(:playa_del_carmen)

    overdue = Patient.create!(practice: practice, firstname: 'Overdue', lastname: 'Follow',
                               uid: 'FU01', date_of_birth: Date.new(1985, 5, 5))
    Appointment.create!(datebook: datebook, doctor: doctor, patient: overdue,
                         starts_at: 8.months.ago, ends_at: 8.months.ago + 30.minutes,
                         status: Appointment.status[:confirmed])

    recent = Patient.create!(practice: practice, firstname: 'Recent', lastname: 'Visit',
                              uid: 'FU02', date_of_birth: Date.new(1990, 1, 1))
    Appointment.create!(datebook: datebook, doctor: doctor, patient: recent,
                         starts_at: 2.months.ago, ends_at: 2.months.ago + 30.minutes,
                         status: Appointment.status[:confirmed])

    scheduled = Patient.create!(practice: practice, firstname: 'Has', lastname: 'Future',
                                 uid: 'FU03', date_of_birth: Date.new(1992, 3, 3))
    Appointment.create!(datebook: datebook, doctor: doctor, patient: scheduled,
                         starts_at: 7.months.ago, ends_at: 7.months.ago + 30.minutes,
                         status: Appointment.status[:confirmed])
    Appointment.create!(datebook: datebook, doctor: doctor, patient: scheduled,
                         starts_at: 2.weeks.from_now, ends_at: 2.weeks.from_now + 30.minutes,
                         status: Appointment.status[:confirmed])

    results = Patient.with_practice(practice.id).needs_follow_up
    result_ids = results.pluck(:id)

    assert_includes result_ids, overdue.id
    refute_includes result_ids, recent.id
    refute_includes result_ids, scheduled.id
  end
end
