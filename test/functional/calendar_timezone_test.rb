# frozen_string_literal: true

require 'test_helper'

class CalendarTimezoneTest < ActionController::TestCase
  tests AppointmentsController

  setup do
    @previous_time_zone = Time.zone
  end

  teardown do
    Time.zone = @previous_time_zone
  end

  # Explicit offsets keep the expectations independent of the parser under test.
  CASES = [
    ['America/Cancun', '2026-03-08', '-05:00'],
    ['America/New_York', '2026-03-08', '-04:00'],
    ['America/New_York', '2026-11-01', '-05:00'],
    ['Europe/London', '2026-03-29', '+01:00'],
    ['Europe/London', '2026-10-25', '+00:00'],
    ['Australia/Sydney', '2026-04-05', '+10:00'],
    ['Australia/Sydney', '2026-10-04', '+11:00'],
    ['Australia/Lord_Howe', '2026-04-05', '+10:30'],
    ['Australia/Lord_Howe', '2026-10-04', '+11:00'],
    ['Asia/Kathmandu', '2026-09-03', '+05:45'],
    ['Pacific/Kiritimati', '2027-01-01', '+14:00'],
    ['Pacific/Pago_Pago', '2026-12-31', '-11:00']
  ].freeze

  %i[founder perishable].each do |role|
    CASES.each do |zone, date, offset|
      test "#{role} calendar round trip in #{zone} on #{date}" do
        user = users(role)
        user.practice.update!(timezone: zone)
        @controller.session['user'] = user
        source = appointments(:first_visit)
        expected_start = Time.iso8601("#{date}T09:00:00#{offset}")

        get :new, params: { datebook_id: source.datebook_id, starts_at: "#{date}T09:00:00" }
        assert_response :success
        assert_equal expected_start, assigns(:appointment).starts_at
        hidden_start = css_select('input[name="appointment[starts_at]"]').first['value']
        assert_not_empty hidden_start

        assert_difference 'Appointment.count', 1 do
          post :create, params: { datebook_id: source.datebook_id, appointment: {
            doctor_id: source.doctor_id, patient_id: source.patient_id, starts_at: hidden_start
          } }, format: :js
        end
        assert_response :success
        appointment = assigns(:appointment).reload
        assert_equal expected_start, appointment.starts_at
        assert_equal expected_start + 1.hour, appointment.ends_at
        assert_schedule_time(appointment, date, '09:00:00', '10:00:00', offset)

        # Moving, resizing, and then refreshing must not reapply a timezone offset.
        patch :update, params: { datebook_id: source.datebook_id, id: appointment.id, appointment: {
          starts_at: "#{date}T10:30:00", ends_at: "#{date}T11:30:00"
        } }, format: :js
        assert_response :success
        assert_equal expected_start + 90.minutes, appointment.reload.starts_at
        assert_equal expected_start + 150.minutes, appointment.ends_at

        patch :update, params: { datebook_id: source.datebook_id, id: appointment.id, appointment: {
          starts_at: "#{date}T10:30:00", ends_at: "#{date}T12:00:00"
        } }, format: :js
        assert_response :success
        assert_equal expected_start + 90.minutes, appointment.reload.starts_at
        assert_equal expected_start + 3.hours, appointment.ends_at
        assert_schedule_time(appointment, date, '10:30:00', '12:00:00', offset)

        saved_times = appointment.attributes.slice('starts_at', 'ends_at')
        patch :update, params: { datebook_id: source.datebook_id, id: appointment.id,
                                 appointment: { notes: 'Unrelated edit', status: 'cancelled' } }, format: :js
        assert_response :success
        assert_equal saved_times, appointment.reload.attributes.slice('starts_at', 'ends_at')
      end
    end
  end

  [
    ['America/New_York', '2026-03-07', '-05:00', '2026-03-08', '-04:00'],
    ['America/New_York', '2026-10-31', '-04:00', '2026-11-01', '-05:00'],
    ['Australia/Lord_Howe', '2026-04-04', '+11:00', '2026-04-05', '+10:30'],
    ['Australia/Lord_Howe', '2026-10-03', '+10:30', '2026-10-04', '+11:00']
  ].each do |zone, old_date, old_offset, new_date, new_offset|
    test "move across #{zone} daylight saving on #{new_date}" do
      user = users(:founder)
      user.practice.update!(timezone: zone)
      @controller.session['user'] = user
      appointment = appointments(:first_visit)
      starts_at = Time.iso8601("#{old_date}T09:00:00#{old_offset}")
      appointment.update!(starts_at: starts_at, ends_at: starts_at + 1.hour)

      patch :update, params: { datebook_id: appointment.datebook_id, id: appointment.id, appointment: {
        starts_at: "#{new_date}T09:00:00", ends_at: "#{new_date}T10:00:00"
      } }, format: :js
      assert_response :success
      assert_equal Time.iso8601("#{new_date}T09:00:00#{new_offset}"), appointment.reload.starts_at
      assert_equal Time.iso8601("#{new_date}T10:00:00#{new_offset}"), appointment.ends_at
      assert_schedule_time(appointment, new_date, '09:00:00', '10:00:00', new_offset)
    end
  end

  private

  def assert_schedule_time(appointment, date, starts_at, ends_at, offset)
    saved_times = appointment.reload.attributes.slice('starts_at', 'ends_at')
    2.times do
      get :index, params: { datebook_id: appointment.datebook_id, doctor_id: appointment.doctor_id,
                            start: "#{date}T00:00:00", end: "#{Date.iso8601(date) + 1}T00:00:00" }, format: :json
      assert_response :success
      result = JSON.parse(response.body).find { |entry| entry['id'] == appointment.id }
      assert_not_nil result
      assert_equal "#{date}T#{starts_at}#{offset}", result.fetch('start').sub(/Z\z/, '+00:00')
      assert_equal "#{date}T#{ends_at}#{offset}", result.fetch('end').sub(/Z\z/, '+00:00')
      assert_equal saved_times, appointment.reload.attributes.slice('starts_at', 'ends_at')
    end

    get :index, params: { datebook_id: appointment.datebook_id, doctor_id: appointment.doctor_id,
                          start: "#{date}T00:00:00", end: "#{Date.iso8601(date) + 1}T00:00:00",
                          wall_clock: '1' }, format: :json
    assert_response :success
    result = JSON.parse(response.body).find { |entry| entry['id'] == appointment.id }
    assert_equal "#{date}T#{starts_at}", result.fetch('start')
    assert_equal "#{date}T#{ends_at}", result.fetch('end')
    assert_equal saved_times, appointment.reload.attributes.slice('starts_at', 'ends_at')
  end
end
