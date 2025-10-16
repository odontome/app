# frozen_string_literal: true

require 'test_helper'
require 'icalendar'

class DoctorsControllerTest < ActionController::TestCase
  setup do
    @controller.session['user'] = users(:founder)

    @new_doctor = { firstname: 'Ruth',
                    lastname: 'Riera',
                    email: 'ruthriera@dentifels.com' }
  end

  test 'should get index' do
    get :index
    assert_response :success
    assert_not_nil assigns(:doctors)
  end

  test 'should get new' do
    get :new
    assert_response :success
  end

  test 'should create doctor' do
    assert_difference('Doctor.count') do
      post :create, params: { doctor: @new_doctor }
    end
    assert_redirected_to doctors_url
  end

  test 'should show doctor' do
    get :show, params: { id: doctors(:rebecca).to_param }
    assert_response :success
  end

  test 'should get edit' do
    get :edit, params: { id: doctors(:rebecca).to_param }
    assert_response :success
  end

  test 'should get calendar subscription' do
    doctor = doctors(:rebecca)
    ciphered_url_encoded_id = Cipher.encode(doctor.id.to_s)

    get :appointments, params: { doctor_id: ciphered_url_encoded_id }, format: :ics
    assert_response :success
  end

  test 'appointments calendar responds with valid ics payload' do
    doctor = doctors(:rebecca)
    ciphered_url_encoded_id = Cipher.encode(doctor.id.to_s)

    get :appointments, params: { doctor_id: ciphered_url_encoded_id }, format: :ics

    assert_response :success
    assert_equal 'text/calendar', @response.media_type

    calendars = Icalendar::Calendar.parse(@response.body)
    assert_not_empty calendars
  end

  test 'appointments with invalid base64 doctor_id returns 404' do
    # Test with invalid base64 string (contains newline which makes it invalid strict base64)
    invalid_doctor_id = "U2FsdGVkX19D+bQnj+nU+P5ZsnaTNFKsgVyj4SwsKVA=\n"

    get :appointments, params: { doctor_id: invalid_doctor_id }, format: :ics

    assert_response :not_found
  end

  test 'appointments with invalid encrypted doctor_id returns 404' do
    # Test with valid base64 but invalid encrypted content
    invalid_encrypted = Base64.strict_encode64('invalid encrypted content')

    get :appointments, params: { doctor_id: invalid_encrypted }, format: :ics

    assert_response :not_found
  end

  test 'appointments with nonexistent doctor returns 404' do
    # Test with valid encryption but nonexistent doctor ID
    nonexistent_id = Cipher.encode('999999')

    get :appointments, params: { doctor_id: nonexistent_id }, format: :ics

    assert_response :not_found
  end

  test 'appointments with inactive doctor returns 404' do
    # Create an inactive doctor
    doctor = doctors(:rebecca)
    doctor.update(is_active: false)
    ciphered_url_encoded_id = Cipher.encode(doctor.id.to_s)

    get :appointments, params: { doctor_id: ciphered_url_encoded_id }, format: :ics

    assert_response :not_found
  end

  test 'should update doctor' do
    put :update, params: { id: doctors(:rebecca).to_param, doctor: @new_doctor }
    assert_redirected_to doctors_url
  end

  test 'should destroy doctor' do
    assert_difference('Doctor.count', -1) do
      delete :destroy, params: { id: doctors(:perishable).to_param }
    end

    assert_redirected_to doctors_path
  end
end
