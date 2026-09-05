# frozen_string_literal: true

require 'test_helper'

class AppointmentsControllerTest < ActionController::TestCase
  setup do
    @controller.session['user'] = users(:founder)
  end

  test 'should get index' do
    start_ts = 1.month.ago.to_i
    end_ts   = 1.month.from_now.to_i
    get :index, params: { datebook_id: 1, start: start_ts, end: end_ts }, format: :json
    assert_response :success
    assert_not_nil assigns(:appointments)
  end

  test 'should return empty array when index is missing date params' do
    get :index, params: { datebook_id: 1 }, format: :json
    assert_response :success
    assert_equal '[]', response.body
  end

  test 'should get new' do
    get :new, params: { datebook_id: 1 }
    assert_response :success
  end

  test 'calendar date range and click use practice time including daylight saving' do
    practice = users(:founder).practice
    practice.update!(timezone: 'Eastern Time (US & Canada)')
    appointment = appointments(:first_visit)

    { '2026-09-03' => 12, '2026-12-03' => 13 }.each do |date, utc_hour|
      starts_at = Time.iso8601("#{date}T#{utc_hour}:00:00Z")
      appointment.update!(starts_at: starts_at, ends_at: starts_at + 1.hour)
      get :index, params: { datebook_id: appointment.datebook_id, start: "#{date}T00:00:00", end: "#{date}T09:00:00" }, format: :json
      assert_response :success
      result = JSON.parse(response.body).find { |entry| entry['id'] == appointment.id }
      assert_equal "#{date}T08:00:00", result.fetch('start')[0, 19]

      get :new, params: { datebook_id: appointment.datebook_id, starts_at: "#{date}T08:00:00" }, format: :html
      assert_equal starts_at, assigns(:appointment).starts_at
    end
  end

  test 'calendar wall-clock feed omits offsets without changing the default JSON contract' do
    practice = users(:founder).practice
    practice.update!(timezone: 'Eastern Time (US & Canada)')
    appointment = appointments(:first_visit)
    starts_at = Time.iso8601('2026-09-03T12:00:00Z')
    appointment.update!(starts_at: starts_at, ends_at: starts_at + 1.hour)

    get :index, params: {
      datebook_id: appointment.datebook_id,
      start: '2026-09-03T00:00:00',
      end: '2026-09-04T00:00:00',
      wall_clock: '1'
    }, format: :json
    wall_clock_event = JSON.parse(response.body).find { |entry| entry['id'] == appointment.id }
    assert_equal '2026-09-03T08:00:00', wall_clock_event.fetch('start')
    assert_equal '2026-09-03T09:00:00', wall_clock_event.fetch('end')

    get :index, params: {
      datebook_id: appointment.datebook_id,
      start: '2026-09-03T00:00:00',
      end: '2026-09-04T00:00:00'
    }, format: :json
    default_event = JSON.parse(response.body).find { |entry| entry['id'] == appointment.id }
    assert_equal '2026-09-03T08:00:00-04:00', default_event.fetch('start')
    assert_equal '2026-09-03T09:00:00-04:00', default_event.fetch('end')
  end

  test 'calendar create move and resize preserve practice wall time' do
    users(:founder).practice.update!(timezone: 'Eastern Time (US & Canada)')
    source = appointments(:first_visit)
    post :create, params: { datebook_id: source.datebook_id, appointment: {
      doctor_id: source.doctor_id, patient_id: source.patient_id, starts_at: '2026-09-03T08:00:00'
    } }, format: :js
    assert_response :success
    appointment = Appointment.last
    assert_equal Time.utc(2026, 9, 3, 12), appointment.starts_at
    assert_equal Time.utc(2026, 9, 3, 13), appointment.ends_at

    patch :update, params: { datebook_id: source.datebook_id, id: appointment.id, appointment: {
      starts_at: '2026-09-04T08:15:00', ends_at: '2026-09-04T09:45:00'
    } }, format: :js
    assert_response :success
    assert_equal Time.utc(2026, 9, 4, 12, 15), appointment.reload.starts_at
    assert_equal Time.utc(2026, 9, 4, 13, 45), appointment.ends_at
  end

  test 'calendar still accepts Unix timestamps for existing clients' do
    source = appointments(:first_visit)
    starts_at = Time.utc(2026, 9, 3, 12)
    post :create, params: { datebook_id: source.datebook_id, appointment: {
      doctor_id: source.doctor_id, patient_id: source.patient_id, starts_at: starts_at.to_i.to_s
    } }, format: :js
    assert_response :success
    assert_equal starts_at, Appointment.last.starts_at
  end

  test 'should create an appointment with an existing patient' do
    appointment = {
      doctor_id: 1,
      starts_at: '2014-01-04 14:00:00 +0000',
      ends_at: '2014-01-04 15:00:00 +0000'
    }

    assert_difference 'Appointment.count' do
      post :create, params: { appointment: appointment, datebook_id: 1, as_values_patient_id: '4,' }, format: :js
      # see Patient.find_or_create_from to understand the 'as_values_patient_id' property
    end
  end

  test 'should ask the browser to reload when the CSRF token is stale' do
    appointment = {
      doctor_id: 1,
      starts_at: '2014-01-04 14:00:00 +0000',
      ends_at: '2014-01-04 15:00:00 +0000'
    }

    ActionController::Base.allow_forgery_protection = true
    assert_no_difference 'Appointment.count' do
      post :create, params: { appointment: appointment, datebook_id: 1, as_values_patient_id: '4,' }, format: :js
    end

    assert_response :success
    assert_includes response.body, 'window.location.reload'
    # the message is JavaScript-escaped in the response, so match a plain part of it
    assert_includes response.body, 'Please try again.'
  ensure
    ActionController::Base.allow_forgery_protection = false
  end

  test 'should create an appointment with a new patient' do
    appointment = {
      doctor_id: 2,
      starts_at: '2014-01-04 14:00:00 +0000',
      ends_at: '2014-01-04 15:00:00 +0000'
    }

    assert_difference ['Patient.count', 'Appointment.count'] do
      post :create, params: { appointment: appointment, datebook_id: 1, as_values_patient_id: 'New patient' },
                    format: :js
      # see Patient.find_or_create_from to understand the 'as_values_patient_id' property
    end
  end

  test 'should update existing appointment with a brand new patient' do
    # in this particular `update` action, the practice_id will come as a string from the textfield
    # with a combination of empty `as_values_patient_id` when adding a new patient, and a number
    # when selecting an existing patient
    appointment_params = {
      starts_at: '2014-01-04 14:00:00 +0000',
      ends_at: '2014-01-04 15:00:00 +0000',
      patient_id: nil 
    }

    appointment = Appointment.find(1)

    assert_difference ['Patient.count'] do
      patch :update, params: { appointment: appointment_params, datebook_id: 1, id: appointment.id, as_values_patient_id: 'Another new patient' },
                    format: :js
      # see Patient.find_or_create_from to understand the 'as_values_patient_id' property
    end

    updated_appointment = Appointment.find(1)

    assert_not_equal appointment.patient, updated_appointment.patient
    assert_equal updated_appointment.patient.firstname, 'Another'
    assert_equal updated_appointment.patient.lastname, 'new patient'
  end

  test 'should update existing appointment with another existing patient' do
    # in this particular `update` action, the practice_id will come as a string from the textfield
    # with a combination of empty `as_values_patient_id` when adding a new patient, and a number
    # when selecting an existing patient
    appointment_params = {
      starts_at: '2014-01-04 14:00:00 +0000',
      ends_at: '2014-01-04 15:00:00 +0000',
      patient_id: '2'
    }

    appointment = Appointment.find(1)

    assert_no_difference ['Patient.count'] do
      patch :update, params: { appointment: appointment_params, datebook_id: 1, id: appointment.id, as_values_patient_id: 'Raul Riera' },
                    format: :js
      # see Patient.find_or_create_from to understand the 'as_values_patient_id' property
    end

    updated_appointment = Appointment.find(1)

    assert_not_equal appointment.patient, updated_appointment.patient
    assert_equal updated_appointment.patient.firstname, 'Miguel'
    assert_equal updated_appointment.patient.lastname, 'Camacho'
  end

  test 'should update appointments by only changing dates' do
    current_time = Time.now
    new_ends_at = current_time + 60.minutes

    appointment = {
      id: 1,
      datebook_id: 1,
      starts_at: current_time,
      ends_at: new_ends_at
    }

    patch :update, params: { appointment: appointment, datebook_id: appointment[:datebook_id], id: appointment[:id] },
                   format: :js
    updated_appointment = Appointment.find(appointment[:id])

    assert_equal updated_appointment.ends_at.to_time.to_i, new_ends_at.to_time.to_i
  end

  test 'should alert when appointment not found' do
    get :show, params: { datebook_id: 1, id: 999999 }, format: :html
    assert_response :success
    assert_includes response.body, "alert("
  end

  test 'should not create an appointment with in a foreign practice' do
    appointment = {
      doctor_id: 2,
      starts_at: '2014-01-04 14:00:00 +0000',
      ends_at: '2014-01-04 15:00:00 +0000'
    }

    assert_no_difference ['Appointment.count'] do
      post :create, params: { appointment: appointment, datebook_id: 99, as_values_patient_id: 'New patient' },
                    format: :js
      # see Patient.find_or_create_from to understand the 'as_values_patient_id' property
    end
  end
end
