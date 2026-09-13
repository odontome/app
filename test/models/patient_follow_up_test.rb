# frozen_string_literal: true

require 'test_helper'

class PatientFollowUpTest < ActiveSupport::TestCase
  test 'count eligibility matches the listing at visit and appointment boundaries' do
    # Match PostgreSQL's transaction clock, which the existing last-visit lookup uses.
    travel_to ActiveRecord::Base.connection.select_value('SELECT CURRENT_TIMESTAMP').to_time do
      now = Time.current
      cutoff = 6.months.ago
      cases = {
        never: [nil, true],
        old: [{ ends_at: cutoff - 1.second }, true],
        boundary: [{ ends_at: cutoff }, false],
        recent: [{ ends_at: cutoff + 1.second }, false],
        ending_now: [{ ends_at: now }, false],
        ongoing: [{ starts_at: now - 30.minutes, ends_at: now + 30.minutes }, true],
        starts_now: [{ starts_at: now, ends_at: now + 30.minutes }, true],
        future: [{ starts_at: now + 1.second, ends_at: now + 30.minutes }, false],
        future_unconfirmed: [{ starts_at: now + 1.day, ends_at: now + 1.day + 30.minutes, status: 'unconfirmed' }, false],
        future_cancelled: [{ starts_at: now + 1.day, ends_at: now + 1.day + 30.minutes, status: 'cancelled' }, true],
        recent_cancelled: [{ ends_at: now - 1.day, status: 'cancelled' }, true],
        recent_waiting: [{ ends_at: now - 1.day, status: 'waiting_room' }, true],
        null_end: [{ starts_at: now - 1.day, ends_at: nil }, true],
        null_status: [{ starts_at: now + 1.day, ends_at: now + 1.day + 30.minutes, status: nil }, true]
      }
      expected = []
      ids = cases.map do |name, (attributes, eligible)|
        patient = Patient.create!(practice: practices(:complete), firstname: name.to_s, lastname: 'Boundary', date_of_birth: '1990-01-01')
        if attributes
          attributes = { status: 'confirmed', starts_at: attributes[:ends_at]&.-(30.minutes) }.merge(attributes)
          Appointment.insert_all!([attributes.merge(patient_id: patient.id, doctor_id: doctors(:rebecca).id,
            datebook_id: datebooks(:playa_del_carmen).id)])
        end
        expected << patient.id if eligible
        patient.id
      end

      scope = Patient.with_practice(practices(:complete).id).where(id: ids)
      count_scope = scope.needs_follow_up.reselect('patients.id')
      assert_equal expected.sort, count_scope.reorder(:id).pluck(:id)
      assert_equal expected.size, count_scope.count
    end
  end

  test 'any recent confirmed visit excludes a patient even when an older visit exists' do
    patient = patients(:one)
    patient.appointments.delete_all
    [8.months.ago, 1.month.ago].each do |ends_at|
      Appointment.insert_all!([{ patient_id: patient.id, doctor_id: doctors(:rebecca).id,
        datebook_id: datebooks(:playa_del_carmen).id, starts_at: ends_at - 30.minutes, ends_at: ends_at, status: 'confirmed' }])
    end
    assert_empty Patient.where(id: patient.id).needs_follow_up
  end

  test 'future appointment status is treated as a value even when it contains SQL syntax' do
    cancelled_status = "cancelled' OR '1'='1"
    ids = [cancelled_status, 'confirmed'].map do |status|
      patient = Patient.create!(practice: practices(:complete), firstname: 'Quoted', lastname: 'Status', date_of_birth: '1990-01-01')
      Appointment.insert_all!([{ patient_id: patient.id, doctor_id: doctors(:rebecca).id,
        datebook_id: datebooks(:playa_del_carmen).id, starts_at: 1.day.from_now,
        ends_at: 1.day.from_now + 30.minutes, status: status }])
      patient.id
    end

    Appointment.stub :status, Appointment.status.merge(cancelled: cancelled_status) do
      assert_equal [ids.first], Patient.where(id: ids).without_upcoming_appointment.pluck(:id)
    end
  end

  test 'prepared follow-up queries preserve indexed last visits and a fixed future status' do
    connection = ActiveRecord::Base.connection
    query = nil
    subscriber = ->(_name, _start, _finish, _id, payload) do
      query = payload if payload[:name] == 'Patient Load'
    end
    ActiveSupport::Notifications.subscribed(subscriber, 'sql.active_record') do
      Patient.with_practice(practices(:complete).id).needs_follow_up.load
    end
    assert query
    # On tiny fixtures a sequential scan is cheaper; this checks index eligibility,
    # including after PostgreSQL switches a frequently used prepared query to a generic plan.
    connection.execute('SET LOCAL enable_seqscan = off')
    connection.execute('SET LOCAL plan_cache_mode = force_generic_plan')
    connection.execute("PREPARE patient_follow_up_indexes AS #{query[:sql]}")
    prepared = true
    values = query[:binds].map { |bind| connection.quote(bind.respond_to?(:value_for_database) ? bind.value_for_database : bind) }.join(', ')
    plan = connection.select_value("EXPLAIN (FORMAT JSON) EXECUTE patient_follow_up_indexes(#{values})")
    assert_includes plan, 'index_appointments_on_patient_id_and_ends_at_confirmed'
    # PostgreSQL may prefer the general starts_at index on tiny fixtures. Either
    # choice is valid, but a bound status would prevent use of the partial index.
    assert_no_match(/status[^\n]*\$\d+/, plan)
  ensure
    connection.execute('DEALLOCATE patient_follow_up_indexes') if prepared
  end

  test 'birthdays respect practice timezone and year rollover including the seventh day' do
    travel_to Time.utc(2026, 12, 31, 1) do
      birthdays = ['1990-12-29', '1990-12-30', '1990-12-31', '1990-01-05', '1990-01-06', nil]
      ids = birthdays.map do |birthday|
        Patient.insert_all!([{ practice_id: practices(:complete).id, firstname: 'Birthday', lastname: 'Boundary', date_of_birth: birthday }], returning: %w[id]).rows.flatten.first
      end
      scope = Patient.with_practice(practices(:complete).id).where(id: ids)
      assert_equal ids.values_at(1, 2, 3).sort, scope.birthday_this_week('America/Los_Angeles').reorder(:id).pluck(:id)
      assert_equal ids.values_at(2, 3, 4).sort, scope.birthday_this_week('UTC').reorder(:id).pluck(:id)
    end
  end
end
