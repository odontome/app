# frozen_string_literal: true

require 'test_helper'

class Api::Mcp::AppointmentsControllerTest < ActionController::TestCase
  setup do
    @controller.session['user'] = users(:founder)
  end

  test 'should get index' do
    get :index, format: :json
    assert_response :success
    json_response = JSON.parse(response.body)
    assert json_response.is_a?(Array)
  end

  test 'should show appointment' do
    get :show, params: { id: appointments(:confirmed).id }, format: :json
    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal appointments(:confirmed).id, json_response['id']
  end

  test 'should create appointment' do
    appointment_params = {
      datebook_id: datebooks(:main).id,
      doctor_id: doctors(:main).id,
      patient_id: patients(:john).id,
      starts_at: 1.hour.from_now,
      notes: 'Test appointment'
    }

    assert_difference 'Appointment.count' do
      post :create, params: { appointment: appointment_params }, format: :json
    end
    assert_response :created
  end

  test 'should update appointment' do
    patch :update, params: { 
      id: appointments(:confirmed).id, 
      appointment: { notes: 'Updated notes' } 
    }, format: :json
    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal 'Updated notes', json_response['notes']
  end

  test 'should destroy appointment' do
    assert_difference 'Appointment.count', -1 do
      delete :destroy, params: { id: appointments(:confirmed).id }, format: :json
    end
    assert_response :no_content
  end

  test 'should not show appointment from different practice' do
    @controller.session['user'] = users(:other_practice)
    
    get :show, params: { id: appointments(:confirmed).id }, format: :json
    assert_response :not_found
  end

  test 'should require authentication' do
    @controller.session['user'] = nil
    
    get :index, format: :json
    assert_response :redirect
  end
end