# frozen_string_literal: true

require 'test_helper'

class Api::McpControllerTest < ActionController::TestCase
  setup do
    @controller.session['user'] = users(:founder)
  end

  test 'should get capabilities' do
    get :capabilities, format: :json
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert json_response['capabilities']
    assert json_response['capabilities']['tools']
    assert json_response['capabilities']['resources']
    assert json_response['serverInfo']
    assert_equal '2024-11-05', json_response['protocolVersion']
  end

  test 'should handle appointments list request' do
    request_data = {
      jsonrpc: '2.0',
      method: 'appointments/list',
      params: { limit: 10 },
      id: 1
    }

    post :handle_request, body: request_data.to_json, format: :json
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert_equal '2.0', json_response['jsonrpc']
    assert json_response['result'].is_a?(Array)
    assert_equal 1, json_response['id']
  end

  test 'should handle appointments get request' do
    request_data = {
      jsonrpc: '2.0',
      method: 'appointments/get',
      params: { id: appointments(:confirmed).id },
      id: 2
    }

    post :handle_request, body: request_data.to_json, format: :json
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert_equal '2.0', json_response['jsonrpc']
    assert_equal appointments(:confirmed).id, json_response['result']['id']
    assert_equal 2, json_response['id']
  end

  test 'should handle appointments create request' do
    request_data = {
      jsonrpc: '2.0',
      method: 'appointments/create',
      params: {
        datebook_id: datebooks(:main).id,
        doctor_id: doctors(:main).id,
        patient_id: patients(:john).id,
        starts_at: 1.hour.from_now.iso8601,
        notes: 'Test appointment'
      },
      id: 3
    }

    assert_difference 'Appointment.count' do
      post :handle_request, body: request_data.to_json, format: :json
    end
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert_equal '2.0', json_response['jsonrpc']
    assert json_response['result']['id']
    assert_equal 3, json_response['id']
  end

  test 'should handle appointments update request' do
    request_data = {
      jsonrpc: '2.0',
      method: 'appointments/update',
      params: {
        id: appointments(:confirmed).id,
        notes: 'Updated notes via MCP'
      },
      id: 4
    }

    post :handle_request, body: request_data.to_json, format: :json
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert_equal '2.0', json_response['jsonrpc']
    assert_equal 'Updated notes via MCP', json_response['result']['notes']
    assert_equal 4, json_response['id']
  end

  test 'should handle appointments delete request' do
    request_data = {
      jsonrpc: '2.0',
      method: 'appointments/delete',
      params: { id: appointments(:confirmed).id },
      id: 5
    }

    assert_difference 'Appointment.count', -1 do
      post :handle_request, body: request_data.to_json, format: :json
    end
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert_equal '2.0', json_response['jsonrpc']
    assert json_response['result']['deleted']
    assert_equal 5, json_response['id']
  end

  test 'should handle datebooks list request' do
    request_data = {
      jsonrpc: '2.0',
      method: 'datebooks/list',
      params: {},
      id: 6
    }

    post :handle_request, body: request_data.to_json, format: :json
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert_equal '2.0', json_response['jsonrpc']
    assert json_response['result'].is_a?(Array)
    assert_equal 6, json_response['id']
  end

  test 'should handle datebooks get request' do
    request_data = {
      jsonrpc: '2.0',
      method: 'datebooks/get',
      params: { id: datebooks(:main).id },
      id: 7
    }

    post :handle_request, body: request_data.to_json, format: :json
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert_equal '2.0', json_response['jsonrpc']
    assert_equal datebooks(:main).id, json_response['result']['id']
    assert_equal 7, json_response['id']
  end

  test 'should handle datebooks create request' do
    request_data = {
      jsonrpc: '2.0',
      method: 'datebooks/create',
      params: {
        name: 'New Datebook via MCP',
        starts_at: '08:00',
        ends_at: '17:00'
      },
      id: 8
    }

    assert_difference 'Datebook.count' do
      post :handle_request, body: request_data.to_json, format: :json
    end
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert_equal '2.0', json_response['jsonrpc']
    assert json_response['result']['id']
    assert_equal 8, json_response['id']
  end

  test 'should handle datebooks update request' do
    request_data = {
      jsonrpc: '2.0',
      method: 'datebooks/update',
      params: {
        id: datebooks(:main).id,
        name: 'Updated Datebook via MCP'
      },
      id: 9
    }

    post :handle_request, body: request_data.to_json, format: :json
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert_equal '2.0', json_response['jsonrpc']
    assert_equal 'Updated Datebook via MCP', json_response['result']['name']
    assert_equal 9, json_response['id']
  end

  test 'should return method not found for invalid method' do
    request_data = {
      jsonrpc: '2.0',
      method: 'invalid/method',
      params: {},
      id: 10
    }

    post :handle_request, body: request_data.to_json, format: :json
    assert_response :bad_request
    
    json_response = JSON.parse(response.body)
    assert_equal '2.0', json_response['jsonrpc']
    assert_equal -32601, json_response['error']['code']
    assert_equal 'Method not found', json_response['error']['message']
    assert_equal 10, json_response['id']
  end

  test 'should return parse error for invalid JSON' do
    post :handle_request, body: 'invalid json', format: :json
    assert_response :bad_request
    
    json_response = JSON.parse(response.body)
    assert_equal '2.0', json_response['jsonrpc']
    assert_equal -32700, json_response['error']['code']
    assert_equal 'Parse error', json_response['error']['message']
  end

  test 'should return invalid request for missing jsonrpc' do
    request_data = {
      method: 'appointments/list',
      params: {},
      id: 11
    }

    post :handle_request, body: request_data.to_json, format: :json
    assert_response :bad_request
    
    json_response = JSON.parse(response.body)
    assert_equal '2.0', json_response['jsonrpc']
    assert_equal -32600, json_response['error']['code']
    assert_equal 'Invalid Request', json_response['error']['message']
  end

  test 'should require authentication' do
    @controller.session.clear
    
    get :capabilities, format: :json
    assert_response :redirect
  end

  test 'should scope data to current practice' do
    # This test ensures appointments are scoped to the current user's practice
    other_practice_user = users(:other_practice_user) # Assuming this fixture exists
    @controller.session['user'] = other_practice_user
    
    request_data = {
      jsonrpc: '2.0',
      method: 'appointments/get',
      params: { id: appointments(:confirmed).id }, # This appointment belongs to founder's practice
      id: 12
    }

    post :handle_request, body: request_data.to_json, format: :json
    assert_response :success
    
    json_response = JSON.parse(response.body)
    # Should return an error since the appointment doesn't belong to the other practice
    assert json_response['error'] || json_response['result'].nil?
  end
end