# frozen_string_literal: true

require 'test_helper'

class Api::Agent::OauthControllerTest < ActionController::TestCase
  setup do
    @practice = practices(:complete)
    @controller = Api::Agent::OauthController.new
    @routes = Rails.application.routes
  end

  # --- redirect URI allowlist ---

  test 'should allow Claude Desktop localhost callback' do
    raw_key = enable_agent_access(@practice)

    get :authorize, params: {
      client_id: raw_key,
      redirect_uri: 'http://localhost:6274/oauth/callback',
      code_challenge: 'test_challenge',
      code_challenge_method: 'S256',
      response_type: 'code',
      state: 'test_state'
    }
    assert_response :redirect
  end

  test 'should allow Claude Desktop debug callback' do
    raw_key = enable_agent_access(@practice)

    get :authorize, params: {
      client_id: raw_key,
      redirect_uri: 'http://localhost:6274/oauth/callback/debug',
      code_challenge: 'test_challenge',
      code_challenge_method: 'S256',
      response_type: 'code',
      state: 'test_state'
    }
    assert_response :redirect
  end

  test 'should allow claude.ai callback' do
    raw_key = enable_agent_access(@practice)

    get :authorize, params: {
      client_id: raw_key,
      redirect_uri: 'https://claude.ai/api/mcp/auth_callback',
      code_challenge: 'test_challenge',
      code_challenge_method: 'S256',
      response_type: 'code',
      state: 'test_state'
    }
    assert_response :redirect
  end

  test 'should allow claude.com callback' do
    raw_key = enable_agent_access(@practice)

    get :authorize, params: {
      client_id: raw_key,
      redirect_uri: 'https://claude.com/api/mcp/auth_callback',
      code_challenge: 'test_challenge',
      code_challenge_method: 'S256',
      response_type: 'code',
      state: 'test_state'
    }
    assert_response :redirect
  end

  test 'should reject arbitrary redirect URI' do
    raw_key = enable_agent_access(@practice)

    get :authorize, params: {
      client_id: raw_key,
      redirect_uri: 'https://evil.com/steal-token',
      code_challenge: 'test_challenge',
      code_challenge_method: 'S256',
      response_type: 'code'
    }
    assert_response :bad_request

    body = JSON.parse(@response.body)
    assert_equal 'invalid_redirect_uri', body['error']
  end

  test 'should reject missing redirect URI' do
    raw_key = enable_agent_access(@practice)

    get :authorize, params: {
      client_id: raw_key,
      code_challenge: 'test_challenge',
      code_challenge_method: 'S256',
      response_type: 'code'
    }
    assert_response :bad_request
  end

  test 'should reject redirect URI with path traversal' do
    raw_key = enable_agent_access(@practice)

    get :authorize, params: {
      client_id: raw_key,
      redirect_uri: 'http://localhost:6274/oauth/callback/../../../steal',
      code_challenge: 'test_challenge',
      code_challenge_method: 'S256',
      response_type: 'code'
    }
    assert_response :bad_request
  end

  # --- OpenAI redirect URIs ---

  test 'should allow ChatGPT oauth callback' do
    raw_key = enable_agent_access(@practice)

    get :authorize, params: {
      client_id: raw_key,
      redirect_uri: 'https://chatgpt.com/oauth/callback',
      code_challenge: 'test_challenge',
      code_challenge_method: 'S256',
      response_type: 'code',
      state: 'test_state'
    }
    assert_response :redirect
  end

  test 'should allow ChatGPT connector platform callback' do
    raw_key = enable_agent_access(@practice)

    get :authorize, params: {
      client_id: raw_key,
      redirect_uri: 'https://chatgpt.com/connector_platform_oauth_redirect',
      code_challenge: 'test_challenge',
      code_challenge_method: 'S256',
      response_type: 'code',
      state: 'test_state'
    }
    assert_response :redirect
  end

  test 'should allow chat.openai.com callback' do
    raw_key = enable_agent_access(@practice)

    get :authorize, params: {
      client_id: raw_key,
      redirect_uri: 'https://chat.openai.com/oauth/callback',
      code_challenge: 'test_challenge',
      code_challenge_method: 'S256',
      response_type: 'code',
      state: 'test_state'
    }
    assert_response :redirect
  end

  test 'should allow OpenAI Platform review callback' do
    raw_key = enable_agent_access(@practice)

    get :authorize, params: {
      client_id: raw_key,
      redirect_uri: 'https://platform.openai.com/apps-manage/oauth',
      code_challenge: 'test_challenge',
      code_challenge_method: 'S256',
      response_type: 'code',
      state: 'test_state'
    }
    assert_response :redirect
  end

  # --- OpenAI domain verification ---

  test 'should return openai apps challenge token' do
    ENV['OPENAI_APPS_CHALLENGE_TOKEN'] = 'test-verification-token-123'

    get :openai_apps_challenge
    assert_response :success
    assert_equal 'text/plain', @response.content_type.split(';').first
    assert_equal 'test-verification-token-123', @response.body
  ensure
    ENV.delete('OPENAI_APPS_CHALLENGE_TOKEN')
  end

  test 'should return empty body when challenge token not configured' do
    ENV.delete('OPENAI_APPS_CHALLENGE_TOKEN')

    get :openai_apps_challenge
    assert_response :success
    assert_equal '', @response.body
  end

  # --- CORS on OAuth endpoints ---

  test 'should return CORS headers for claude.ai on token endpoint' do
    @request.headers['Origin'] = 'https://claude.ai'
    @request.headers['Content-Type'] = 'application/x-www-form-urlencoded'

    post :token, params: {
      grant_type: 'client_credentials',
      client_id: 'test',
      client_secret: 'invalid'
    }

    assert_equal 'https://claude.ai', @response.headers['Access-Control-Allow-Origin']
  end

  test 'should not return CORS headers for unknown origin on token endpoint' do
    @request.headers['Origin'] = 'https://evil.com'
    @request.headers['Content-Type'] = 'application/x-www-form-urlencoded'

    post :token, params: {
      grant_type: 'client_credentials',
      client_id: 'test',
      client_secret: 'invalid'
    }

    assert_nil @response.headers['Access-Control-Allow-Origin']
  end

  private

  def enable_agent_access(practice)
    practice.update!(agent_access_enabled: true)
    practice.generate_agent_api_key!
  end
end
