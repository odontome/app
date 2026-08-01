# frozen_string_literal: true

require 'test_helper'

class Api::Agent::AppointmentsControllerTest < ActionController::TestCase
  setup do
    @practice = practices(:complete)
    @datebook = datebooks(:playa_del_carmen)
    @doctor = doctors(:rebecca)
    @patient = patients(:four)

    @controller = Api::Agent::AppointmentsController.new
    @routes = Rails.application.routes
  end

  test 'should reject requests without api key' do
    get :index, params: { datebook_id: @datebook.id, start: 1.day.ago.to_i, end: Time.now.to_i }, format: :json
    assert_response :unauthorized
  end

  test 'should reject requests when agent access is disabled' do
    raw_key = @practice.generate_agent_api_key!
    @request.headers['X-Agent-Key'] = raw_key

    get :index, params: { datebook_id: @datebook.id, start: 1.day.ago.to_i, end: Time.now.to_i }, format: :json
    assert_response :unauthorized
  end

  test 'should list appointments with redacted payload' do
    raw_key = enable_agent_access(@practice)
    @request.headers['X-Agent-Key'] = raw_key

    get :index, params: { datebook_id: @datebook.id, start: 1.day.ago.to_i, end: 1.day.from_now.to_i }, format: :json
    assert_response :success

    body = JSON.parse(@response.body)
    assert body.is_a?(Array)
    first = body.first

    assert first.key?('id')
    assert first.key?('start')
    assert first.key?('end')
    assert first.key?('doctor_id')
    assert first.key?('doctor_name')
    assert first.key?('datebook_id')
    assert first.key?('datebook_name')
    assert first.key?('patient_id')
    assert first.key?('patient_name')
    assert first.key?('status')
    assert first.key?('notes')

    # Should NOT expose PII
    %w[email phone telephone address date_of_birth allergies insurance].each do |pii_field|
      assert_not first.key?(pii_field), "Appointment must not expose PII field: #{pii_field}"
    end
  end

  test 'should list appointments with datebook name and readable dates' do
    raw_key = enable_agent_access(@practice)
    @request.headers['X-Agent-Key'] = raw_key

    start_time = 1.day.ago.in_time_zone
    end_time = Time.zone.now

    get :index,
        params: {
          datebook_id: @datebook.id,
          datebook_name: @datebook.name,
          start: start_time.strftime('%Y-%m-%d %H:%M:%S'),
          end: end_time.strftime('%Y-%m-%d %H:%M:%S')
        },
        format: :json

    assert_response :success
    body = JSON.parse(@response.body)
    assert body.is_a?(Array)
  end

  test 'should create appointment with existing patient' do
    raw_key = enable_agent_access(@practice)
    @request.headers['X-Agent-Key'] = raw_key

    starts_at = 3.days.from_now.to_i
    ends_at = (3.days.from_now + 1.hour).to_i

    assert_difference 'Appointment.count' do
      post :create,
           params: {
             datebook_id: @datebook.id,
             appointment: {
               doctor_id: @doctor.id,
               patient_id: @patient.id,
               starts_at: starts_at,
               ends_at: ends_at,
               notes: 'Follow-up visit'
             }
           },
           format: :json
    end

    assert_response :created
    body = JSON.parse(@response.body)
    assert body.key?('patient_id')
    assert body.key?('patient_name')
  end

  test 'should create appointment with new patient name' do
    raw_key = enable_agent_access(@practice)
    @request.headers['X-Agent-Key'] = raw_key

    starts_at = 4.days.from_now.to_i
    ends_at = (4.days.from_now + 1.hour).to_i

    assert_difference ['Patient.count', 'Appointment.count'] do
      post :create,
           params: {
             datebook_id: @datebook.id,
             appointment: {
               doctor_id: @doctor.id,
               patient_name: 'New Patient',
               starts_at: starts_at,
               ends_at: ends_at,
               notes: 'First visit'
             }
           },
           format: :json
    end

    assert_response :created
  end

  test 'should update appointment times' do
    raw_key = enable_agent_access(@practice)
    @request.headers['X-Agent-Key'] = raw_key

    appointment = appointments(:first_visit)
    new_starts_at = 5.days.from_now.to_i
    new_ends_at = (5.days.from_now + 1.hour).to_i

    patch :update,
          params: {
            datebook_id: @datebook.id,
            id: appointment.id,
            appointment: {
              starts_at: new_starts_at,
              ends_at: new_ends_at
            }
          },
          format: :json

    assert_response :success

    appointment.reload
    assert_equal Time.at(new_starts_at).to_i, appointment.starts_at.to_i
    assert_equal Time.at(new_ends_at).to_i, appointment.ends_at.to_i
  end

  test 'should return not found for unknown appointment' do
    raw_key = enable_agent_access(@practice)
    @request.headers['X-Agent-Key'] = raw_key

    patch :update,
          params: {
            datebook_id: @datebook.id,
            id: 999999,
            appointment: {
              starts_at: 1.day.from_now.to_i,
              ends_at: (1.day.from_now + 1.hour).to_i
            }
          },
          format: :json

    assert_response :not_found
  end

  test 'should not link an appointment to a patient from another practice' do
    raw_key = enable_agent_access(@practice)
    @request.headers['X-Agent-Key'] = raw_key

    foreign_patient = patients(:three)
    assert_not_equal @practice.id, foreign_patient.practice_id,
                     'fixture precondition: patient must belong to a different practice'

    post :create,
         params: {
           datebook_id: @datebook.id,
           appointment: {
             doctor_id: @doctor.id,
             patient_name: foreign_patient.id.to_s,
             starts_at: 3.days.from_now.to_i,
             ends_at: (3.days.from_now + 1.hour).to_i
           }
         },
         format: :json

    assert_response :unprocessable_entity
    assert_not Appointment.exists?(patient_id: foreign_patient.id, datebook_id: @datebook.id),
               'Must not link an appointment to a patient from another practice'
    assert_not_includes @response.body, foreign_patient.firstname,
                        'Must not leak the name of a patient from another practice'
  end

  test 'should reject creating an appointment for a doctor from another practice' do
    raw_key = enable_agent_access(@practice)
    @request.headers['X-Agent-Key'] = raw_key

    foreign_doctor = foreign_practice_doctor

    assert_no_difference 'Appointment.count' do
      post :create,
           params: {
             datebook_id: @datebook.id,
             appointment: {
               doctor_id: foreign_doctor.id,
               patient_id: @patient.id,
               starts_at: 3.days.from_now.to_i,
               ends_at: (3.days.from_now + 1.hour).to_i
             }
           },
           format: :json
    end

    assert_response :unprocessable_entity
    assert_not_includes @response.body, foreign_doctor.firstname,
                        'Must not leak the name of a doctor from another practice'
  end

  test 'should reject reassigning an appointment to a doctor from another practice' do
    raw_key = enable_agent_access(@practice)
    @request.headers['X-Agent-Key'] = raw_key

    appointment = appointments(:first_visit)
    foreign_doctor = foreign_practice_doctor

    patch :update,
          params: {
            datebook_id: @datebook.id,
            id: appointment.id,
            appointment: { doctor_id: foreign_doctor.id }
          },
          format: :json

    assert_response :unprocessable_entity
    appointment.reload
    assert_not_equal foreign_doctor.id, appointment.doctor_id,
                     'Must not reassign an appointment to a doctor from another practice'
  end

  private

  def foreign_practice_doctor
    Doctor.create!(
      practice_id: practices(:trialing_practice).id,
      firstname: 'Foreign',
      lastname: 'Doctor',
      gender: 'female'
    )
  end

  def enable_agent_access(practice)
    practice.update!(agent_access_enabled: true)
    practice.generate_agent_api_key!
  end
end
