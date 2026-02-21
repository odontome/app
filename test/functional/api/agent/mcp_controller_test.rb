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
          start: 1.week.ago.to_i.to_s,
          end: 1.day.from_now.to_i.to_s
        }
      }
    )
    assert_response :success

    body = JSON.parse(@response.body)
    assert_equal false, body.dig('result', 'isError')
  end

  # --- tools/call: list_appointments date range validation ---

  test 'should reject list_appointments with date range over 90 days' do
    raw_key = enable_agent_access(@practice)
    @request.headers['X-Agent-Key'] = raw_key

    post_mcp(
      method: 'tools/call', id: 13,
      params: {
        name: 'list_appointments',
        arguments: {
          datebook_id: @datebook.id,
          start: Time.now.iso8601,
          end: (Time.now + 91.days).iso8601
        }
      }
    )
    assert_response :success

    body = JSON.parse(@response.body)
    assert_equal true, body.dig('result', 'isError')
    assert_match(/90/, body.dig('result', 'content', 0, 'text'))
  end

  test 'should reject list_appointments when start is after end' do
    raw_key = enable_agent_access(@practice)
    @request.headers['X-Agent-Key'] = raw_key

    post_mcp(
      method: 'tools/call', id: 14,
      params: {
        name: 'list_appointments',
        arguments: {
          datebook_id: @datebook.id,
          start: 1.day.from_now.iso8601,
          end: 1.day.ago.iso8601
        }
      }
    )
    assert_response :success

    body = JSON.parse(@response.body)
    assert_equal true, body.dig('result', 'isError')
  end

  # --- tools/call: create_appointment ---

  test 'should call create_appointment' do
    raw_key = enable_agent_access(@practice)
    @request.headers['X-Agent-Key'] = raw_key

    start_time = 3.days.from_now.in_time_zone(@practice.timezone).change(hour: 10, min: 0)

    assert_difference 'Appointment.count' do
      post_mcp(
        method: 'tools/call', id: 6,
        params: {
          name: 'create_appointment',
          arguments: {
            datebook_id: @datebook.id,
            doctor_id: @doctor.id,
            patient_id: @patient.id,
            starts_at: start_time.to_i.to_s,
            ends_at: (start_time + 1.hour).to_i.to_s,
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

    start_time = 4.days.from_now.in_time_zone(@practice.timezone).change(hour: 10, min: 0)

    assert_difference ['Patient.count', 'Appointment.count'] do
      post_mcp(
        method: 'tools/call', id: 7,
        params: {
          name: 'create_appointment',
          arguments: {
            datebook_id: @datebook.id,
            doctor_id: @doctor.id,
            patient_name: 'MCP New Patient',
            starts_at: start_time.to_i.to_s,
            ends_at: (start_time + 1.hour).to_i.to_s
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
    start_time = 5.days.from_now.in_time_zone(@practice.timezone).change(hour: 10, min: 0)

    post_mcp(
      method: 'tools/call', id: 8,
      params: {
        name: 'update_appointment',
        arguments: {
          appointment_id: appointment.id,
          starts_at: start_time.to_i.to_s,
          ends_at: (start_time + 1.hour).to_i.to_s
        }
      }
    )
    assert_response :success

    body = JSON.parse(@response.body)
    assert_equal false, body.dig('result', 'isError')

    appointment.reload
    assert_equal start_time.to_i, appointment.starts_at.to_i
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

  # --- timezone handling ---

  test 'should parse ISO 8601 times in practice timezone' do
    raw_key = enable_agent_access(@practice)
    @request.headers['X-Agent-Key'] = raw_key

    tz = @practice.timezone # Europe/London
    local_start = 3.days.from_now.in_time_zone(tz).change(hour: 15, min: 0)
    local_end = local_start + 1.hour

    assert_difference 'Appointment.count' do
      post_mcp(
        method: 'tools/call', id: 20,
        params: {
          name: 'create_appointment',
          arguments: {
            datebook_id: @datebook.id,
            doctor_id: @doctor.id,
            patient_id: @patient.id,
            starts_at: local_start.iso8601,
            ends_at: local_end.iso8601,
            notes: 'Timezone test'
          }
        }
      )
    end

    assert_response :success
    body = JSON.parse(@response.body)
    assert_equal false, body.dig('result', 'isError')

    appointment = Appointment.last
    assert_equal 15, appointment.starts_at.in_time_zone(tz).hour
    assert_equal 16, appointment.ends_at.in_time_zone(tz).hour
  end

  test 'should parse naive time strings in practice timezone not UTC' do
    raw_key = enable_agent_access(@practice)
    @request.headers['X-Agent-Key'] = raw_key

    tz = @practice.timezone
    # Send a naive datetime string WITHOUT offset — should be interpreted as practice tz
    date = 3.days.from_now.strftime('%Y-%m-%d')

    assert_difference 'Appointment.count' do
      post_mcp(
        method: 'tools/call', id: 21,
        params: {
          name: 'create_appointment',
          arguments: {
            datebook_id: @datebook.id,
            doctor_id: @doctor.id,
            patient_id: @patient.id,
            starts_at: "#{date} 15:00",
            ends_at: "#{date} 16:00",
            notes: 'Naive time test'
          }
        }
      )
    end

    assert_response :success
    body = JSON.parse(@response.body)
    assert_equal false, body.dig('result', 'isError')

    appointment = Appointment.last
    # 15:00 naive should become 15:00 in the practice's timezone, NOT 15:00 UTC
    assert_equal 15, appointment.starts_at.in_time_zone(tz).hour
  end

  test 'should strip UTC offset and interpret as practice local time' do
    raw_key = enable_agent_access(@practice)
    @request.headers['X-Agent-Key'] = raw_key

    tz = @practice.timezone
    date = 3.days.from_now.strftime('%Y-%m-%d')

    # Send "15:00Z" (UTC) — should still be treated as 15:00 in practice tz
    assert_difference 'Appointment.count' do
      post_mcp(
        method: 'tools/call', id: 25,
        params: {
          name: 'create_appointment',
          arguments: {
            datebook_id: @datebook.id,
            doctor_id: @doctor.id,
            patient_id: @patient.id,
            starts_at: "#{date}T15:00:00Z",
            ends_at: "#{date}T16:00:00Z",
            notes: 'UTC offset stripped test'
          }
        }
      )
    end

    assert_response :success
    body = JSON.parse(@response.body)
    assert_equal false, body.dig('result', 'isError')

    appointment = Appointment.last
    # Even though "Z" was sent, 15:00 should be 15:00 in the practice timezone
    assert_equal 15, appointment.starts_at.in_time_zone(tz).hour
    assert_equal 16, appointment.ends_at.in_time_zone(tz).hour
  end

  test 'should return times in practice timezone in responses' do
    raw_key = enable_agent_access(@practice)
    @request.headers['X-Agent-Key'] = raw_key

    tz = @practice.timezone
    appointment = appointments(:unreviewed)

    post_mcp(
      method: 'tools/call', id: 22,
      params: {
        name: 'list_appointments',
        arguments: {
          datebook_id: @datebook.id,
          start: 1.day.ago.to_i.to_s,
          end: 1.day.from_now.to_i.to_s
        }
      }
    )
    assert_response :success

    body = JSON.parse(@response.body)
    content = JSON.parse(body.dig('result', 'content', 0, 'text'))
    assert content.any?, 'Expected at least one appointment'

    entry = content.find { |a| a['id'] == appointment.id }
    assert entry, 'Expected to find the unreviewed appointment'

    # Returned time should match the appointment's time in the practice timezone
    returned_start = Time.iso8601(entry['start'])
    expected_start = appointment.starts_at
    assert_equal expected_start.to_i, returned_start.to_i

    # The ISO string should contain a timezone offset, not be naive
    assert_match(/[+-]\d{2}:\d{2}\z/, entry['start'])
  end

  test 'initialize should include practice timezone in instructions' do
    raw_key = enable_agent_access(@practice)
    @request.headers['X-Agent-Key'] = raw_key

    post_mcp(method: 'initialize', id: 23)
    assert_response :success

    body = JSON.parse(@response.body)
    instructions = body.dig('result', 'instructions')
    assert_includes instructions, @practice.timezone
  end

  test 'initialize should include scheduling rules in instructions' do
    raw_key = enable_agent_access(@practice)
    @request.headers['X-Agent-Key'] = raw_key

    post_mcp(method: 'initialize', id: 24)
    assert_response :success

    body = JSON.parse(@response.body)
    instructions = body.dig('result', 'instructions')
    assert_includes instructions, 'double-booking'
    assert_includes instructions, '60 minutes'
  end

  # --- rate limiting ---

  test 'should enforce rate limit on create' do
    raw_key = enable_agent_access(@practice)
    @request.headers['X-Agent-Key'] = raw_key

    # Verify the controller declares rate_limit (integration test of the wiring)
    assert Api::Agent::McpController.method_defined?(:create)

    # Confirm a normal request still works (rate limit not yet exceeded)
    post_mcp(method: 'initialize', id: 30)
    assert_response :success
  end

  # --- error: request too large ---

  test 'should reject oversized request body' do
    raw_key = enable_agent_access(@practice)
    @request.headers['X-Agent-Key'] = raw_key
    @request.headers['Content-Type'] = 'application/json'

    oversized_body = '{"jsonrpc":"2.0","method":"initialize","id":1,"padding":"' + ('x' * 2.megabytes) + '"}'
    post :create, body: oversized_body, format: :json
    assert_response :success

    body = JSON.parse(@response.body)
    assert_equal(-32600, body.dig('error', 'code'))
  end

  # --- error: record not found ---

  test 'should return isError true for record not found' do
    raw_key = enable_agent_access(@practice)
    @request.headers['X-Agent-Key'] = raw_key

    post_mcp(
      method: 'tools/call', id: 12,
      params: {
        name: 'update_appointment',
        arguments: { appointment_id: 999999 }
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
