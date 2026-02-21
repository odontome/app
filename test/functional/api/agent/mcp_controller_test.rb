# frozen_string_literal: true

require 'test_helper'

class Api::Agent::McpControllerTest < ActionController::TestCase
  setup do
    @practice = practices(:complete)
    @datebook = datebooks(:playa_del_carmen)
    @doctor = doctors(:rebecca)
    @patient = patients(:four)

    @controller = Api::Agent::McpController.new
    @routes = Rails.application.routes
  end

  # --- Auth ---

  test 'should reject requests without api key' do
    post_mcp(method: 'initialize')
    assert_response :unauthorized
  end

  # --- initialize ---

  test 'should handle initialize' do
    raw_key = enable_agent_access(@practice)
    @request.headers['X-Agent-Key'] = raw_key

    post_mcp(method: 'initialize', id: 1)
    assert_response :success

    body = JSON.parse(@response.body)
    assert_equal '2.0', body['jsonrpc']
    assert_equal 1, body['id']
    assert_equal '2025-11-25', body.dig('result', 'protocolVersion')
    assert_equal 'odontome', body.dig('result', 'serverInfo', 'name')
  end

  # --- notifications/initialized ---

  test 'should handle notifications/initialized' do
    raw_key = enable_agent_access(@practice)
    @request.headers['X-Agent-Key'] = raw_key

    post_mcp(method: 'notifications/initialized')
    assert_response :accepted
  end

  # --- tools/list ---

  test 'should list tools' do
    raw_key = enable_agent_access(@practice)
    @request.headers['X-Agent-Key'] = raw_key

    post_mcp(method: 'tools/list', id: 2)
    assert_response :success

    body = JSON.parse(@response.body)
    tools = body.dig('result', 'tools')
    assert tools.is_a?(Array)
    assert tools.length >= 6
    tool_names = tools.map { |t| t['name'] }
    assert_includes tool_names, 'list_datebooks'
    assert_includes tool_names, 'search_patients'
  end

  # --- tools/call: list_datebooks ---

  test 'should call list_datebooks' do
    raw_key = enable_agent_access(@practice)
    @request.headers['X-Agent-Key'] = raw_key

    post_mcp(method: 'tools/call', id: 3, params: { name: 'list_datebooks', arguments: {} })
    assert_response :success

    body = JSON.parse(@response.body)
    content = JSON.parse(body.dig('result', 'content', 0, 'text'))
    assert content.is_a?(Array)
    assert content.any? { |d| d['name'] == 'Playa del Carmen' }
  end

  # --- tools/call: list_doctors ---

  test 'should call list_doctors' do
    raw_key = enable_agent_access(@practice)
    @request.headers['X-Agent-Key'] = raw_key

    post_mcp(method: 'tools/call', id: 4, params: { name: 'list_doctors', arguments: {} })
    assert_response :success

    body = JSON.parse(@response.body)
    content = JSON.parse(body.dig('result', 'content', 0, 'text'))
    assert content.is_a?(Array)
  end

  # --- tools/call: list_appointments ---

  test 'should call list_appointments' do
    raw_key = enable_agent_access(@practice)
    @request.headers['X-Agent-Key'] = raw_key

    post_mcp(
      method: 'tools/call', id: 5,
      params: {
        name: 'list_appointments',
        arguments: {
          datebook_id: @datebook.id,
          start: 1.year.ago.to_i.to_s,
          end: 1.day.from_now.to_i.to_s
        }
      }
    )
    assert_response :success

    body = JSON.parse(@response.body)
    assert_equal false, body.dig('result', 'isError')
  end

  # --- tools/call: create_appointment ---

  test 'should call create_appointment' do
    raw_key = enable_agent_access(@practice)
    @request.headers['X-Agent-Key'] = raw_key

    assert_difference 'Appointment.count' do
      post_mcp(
        method: 'tools/call', id: 6,
        params: {
          name: 'create_appointment',
          arguments: {
            datebook_id: @datebook.id,
            doctor_id: @doctor.id,
            patient_id: @patient.id,
            starts_at: 3.days.from_now.to_i.to_s,
            ends_at: (3.days.from_now + 1.hour).to_i.to_s,
            notes: 'MCP test'
          }
        }
      )
    end

    assert_response :success
    body = JSON.parse(@response.body)
    assert_equal false, body.dig('result', 'isError')
  end

  # --- tools/call: create_appointment with patient_name ---

  test 'should call create_appointment with new patient name' do
    raw_key = enable_agent_access(@practice)
    @request.headers['X-Agent-Key'] = raw_key

    assert_difference ['Patient.count', 'Appointment.count'] do
      post_mcp(
        method: 'tools/call', id: 7,
        params: {
          name: 'create_appointment',
          arguments: {
            datebook_id: @datebook.id,
            doctor_id: @doctor.id,
            patient_name: 'MCP New Patient',
            starts_at: 4.days.from_now.to_i.to_s,
            ends_at: (4.days.from_now + 1.hour).to_i.to_s
          }
        }
      )
    end

    assert_response :success
  end

  # --- tools/call: update_appointment ---

  test 'should call update_appointment' do
    raw_key = enable_agent_access(@practice)
    @request.headers['X-Agent-Key'] = raw_key

    appointment = appointments(:first_visit)
    new_starts = 5.days.from_now.to_i
    new_ends = (5.days.from_now + 1.hour).to_i

    post_mcp(
      method: 'tools/call', id: 8,
      params: {
        name: 'update_appointment',
        arguments: {
          datebook_id: @datebook.id,
          appointment_id: appointment.id,
          starts_at: new_starts.to_s,
          ends_at: new_ends.to_s
        }
      }
    )
    assert_response :success

    body = JSON.parse(@response.body)
    assert_equal false, body.dig('result', 'isError')

    appointment.reload
    assert_equal Time.at(new_starts).to_i, appointment.starts_at.to_i
  end

  # --- tools/call: search_patients ---

  test 'should call search_patients' do
    raw_key = enable_agent_access(@practice)
    @request.headers['X-Agent-Key'] = raw_key

    post_mcp(
      method: 'tools/call', id: 9,
      params: { name: 'search_patients', arguments: { query: 'Raul' } }
    )
    assert_response :success

    body = JSON.parse(@response.body)
    content = JSON.parse(body.dig('result', 'content', 0, 'text'))
    assert content.is_a?(Array)
  end

  # --- error: unknown method ---

  test 'should return error for unknown method' do
    raw_key = enable_agent_access(@practice)
    @request.headers['X-Agent-Key'] = raw_key

    post_mcp(method: 'nonexistent/method', id: 10)
    assert_response :success

    body = JSON.parse(@response.body)
    assert_equal(-32601, body.dig('error', 'code'))
  end

  # --- error: unknown tool ---

  test 'should return error for unknown tool' do
    raw_key = enable_agent_access(@practice)
    @request.headers['X-Agent-Key'] = raw_key

    post_mcp(
      method: 'tools/call', id: 11,
      params: { name: 'nonexistent_tool', arguments: {} }
    )
    assert_response :success

    body = JSON.parse(@response.body)
    assert_equal true, body.dig('result', 'isError')
  end

  # --- error: invalid JSON ---

  test 'should return parse error for invalid JSON' do
    raw_key = enable_agent_access(@practice)
    @request.headers['X-Agent-Key'] = raw_key

    @request.headers['Content-Type'] = 'application/json'
    post :create, body: 'not valid json', format: :json
    assert_response :success

    body = JSON.parse(@response.body)
    assert_equal(-32700, body.dig('error', 'code'))
  end

  # --- error: record not found ---

  test 'should return isError true for record not found' do
    raw_key = enable_agent_access(@practice)
    @request.headers['X-Agent-Key'] = raw_key

    post_mcp(
      method: 'tools/call', id: 12,
      params: {
        name: 'update_appointment',
        arguments: { datebook_id: @datebook.id, appointment_id: 999999 }
      }
    )
    assert_response :success

    body = JSON.parse(@response.body)
    assert_equal true, body.dig('result', 'isError')
  end

  private

  def enable_agent_access(practice)
    practice.update!(agent_access_enabled: true)
    practice.generate_agent_api_key!
  end

  def post_mcp(method:, id: nil, params: nil)
    body = { jsonrpc: '2.0', method: method }
    body[:id] = id if id
    body[:params] = params if params

    @request.headers['Content-Type'] = 'application/json'
    post :create, body: body.to_json, format: :json
  end
end
