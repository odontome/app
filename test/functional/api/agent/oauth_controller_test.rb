# frozen_string_literal: true

require "test_helper"

class Api::Agent::OauthControllerTest < ActionController::TestCase
  include AgentOauthTestClients

  setup do
    @practice = practices(:complete)
    @user = users(:founder)
    enable_agent_access
    @controller = Api::Agent::OauthController.new
    @test_clients = CLIENTS.deep_dup
    test_clients = @test_clients
    clients = ->(client_id) do
      document = test_clients.values.find { |candidate| candidate['client_id'] == client_id }
      AgentOauthClient.new(client_id, document) if document
    end
    @controller.define_singleton_method(:oauth_client, &clients)
    @routes = Rails.application.routes
  end

  test "publishes protected-resource metadata" do
    get :protected_resource_metadata

    body = JSON.parse(@response.body)
    assert_equal "#{@request.base_url}/api/agent/mcp", body["resource"]
    assert_equal [@request.base_url], body["authorization_servers"]
    assert_equal ["offline_access"], body["scopes_supported"]
    assert_recognizes({ controller: 'api/agent/oauth', action: 'protected_resource_metadata' },
      { path: '/.well-known/oauth-protected-resource/api/agent/mcp', method: :get })
  end

  test "publishes public multi-client OAuth metadata" do
    get :authorization_server_metadata

    body = JSON.parse(@response.body)
    assert_equal @request.base_url, body["issuer"]
    assert_equal ["authorization_code", "refresh_token"], body["grant_types_supported"]
    assert_equal ["S256"], body["code_challenge_methods_supported"]
    assert_equal ["none"], body["token_endpoint_auth_methods_supported"]
    assert_equal true, body["client_id_metadata_document_supported"]
    assert_equal true, body["authorization_response_iss_parameter_supported"]
  end

  test "returns the OpenAI ownership challenge" do
    ENV["OPENAI_APPS_CHALLENGE_TOKEN"] = "challenge-token"
    get :openai_apps_challenge

    assert_response :success
    assert_equal "text/plain", @response.media_type
    assert_equal "challenge-token", @response.body
  ensure
    ENV.delete("OPENAI_APPS_CHALLENGE_TOKEN")
  end

  test "returns an empty ownership challenge when not configured" do
    ENV.delete("OPENAI_APPS_CHALLENGE_TOKEN")
    get :openai_apps_challenge

    assert_response :success
    assert_equal "", @response.body
  end

  test 'production client resolver rejects a non-HTTPS client before network access' do
    assert_nil Api::Agent::OauthController.new.send(:oauth_client, 'http://client.example/metadata.json')
  end

  test 'rate limits authorization and credential endpoints by remote address' do
    store = Api::Agent::OauthController.cache_store
    store.stub(:increment, 31) do
      get :authorize, params: authorization_params
      assert_response :too_many_requests
      assert_equal 'slow_down', JSON.parse(@response.body)['error']
    end
    store.stub(:increment, 61) do
      post :token, params: { grant_type: 'authorization_code' }
      assert_response :too_many_requests
      assert_equal 'slow_down', JSON.parse(@response.body)['error']
      assert_equal 'no-store', @response.headers['Cache-Control']
      assert_equal 'no-cache', @response.headers['Pragma']
    end
  end

  test "rejects authorization requests from unknown clients without redirecting" do
    get :authorize, params: authorization_params(client_id: "https://evil.example/client.json")

    assert_response :bad_request
    assert_select 'h2', text: I18n.t(:agent_oauth_unknown_title)
  end

  test "redirects safe invalid authorization requests with state and issuer" do
    get :authorize, params: authorization_params(response_type: "token", state: "client-state")

    query = redirect_query
    assert_equal "invalid_request", query["error"]
    assert_equal "client-state", query["state"]
    assert_equal @request.base_url, query["iss"]
  end

  test "requires an Odonto.me session before approval" do
    assert_no_difference "AgentOauthAuthorization.count" do
      get :authorize, params: authorization_params
    end

    assert_redirected_to signin_path
    assert_includes @request.session[:return_to], "/api/agent/oauth/authorize"
  end

  test "denies authorization when agent access is disabled" do
    @practice.update!(agent_access_enabled: false)
    @request.session[:user] = @user

    get :authorize, params: authorization_params(state: "denied-state")

    assert_equal "access_denied", redirect_query["error"]
    assert_equal "denied-state", redirect_query["state"]
  end

  test "denies authorization when the practice is not eligible" do
    @practice.subscription.update!(status: "canceled")
    @request.session[:user] = @user

    get :authorize, params: authorization_params(state: "denied-state")

    query = redirect_query
    assert_equal "access_denied", query["error"]
    assert_equal "denied-state", query["state"]
    assert_equal @request.base_url, query["iss"]
  end

  test "denies authorization when the subscription is past due" do
    @practice.subscription.update!(status: "past_due")
    @request.session[:user] = @user

    get :authorize, params: authorization_params(state: "past-due-state")

    query = redirect_query
    assert_equal "access_denied", query["error"]
    assert_equal "past-due-state", query["state"]
  end

  test "requires current terms and privacy consent" do
    @user.user_consents.current_privacy.delete_all
    @request.session[:user] = @user

    get :authorize, params: authorization_params

    assert_redirected_to consent_review_path
    assert_includes @request.session[:return_to], "/api/agent/oauth/authorize"
  end

  test "renders a non-redeemable approval request" do
    authorization, approval_token = begin_authorization(state: "original-state")

    assert_response :success
    assert_select "body.border-top-wide"
    assert_select "img[src*='logo']"
    assert_select ".text-muted", text: /#{Regexp.escape(@user.fullname)}/
    assert_select "form[action='/api/agent/oauth/approve'][method='post']"
    assert_select "input[type=submit][value=?]", I18n.t(:agent_oauth_authorize_button)
    assert_select "input[name=authorization_id]"
    assert_select "input[name=approval_token][value=?]", approval_token
    assert_select "input[name=code]", count: 0
    assert_nil authorization.code_digest
    assert_nil authorization.approved_at
    assert_equal "original-state", authorization.state
  end

  test "does not exchange the approval nonce as an authorization code" do
    _authorization, approval_token = begin_authorization

    post :token, params: token_params(code: approval_token)

    assert_response :bad_request
    assert_equal "invalid_grant", JSON.parse(@response.body)["error"]
    assert_equal 0, AgentOauthAccessToken.count
  end

  test "rejects approval without a signed-in user" do
    authorization, approval_token = begin_authorization
    @controller = Api::Agent::OauthController.new
    @request.session.delete(:user)

    post :approve, params: { authorization_id: authorization.id, approval_token: approval_token }

    assert_response :bad_request
    assert_equal "invalid_request", JSON.parse(@response.body)["error"]
  end

  test "rejects approval from a different signed-in user" do
    authorization, approval_token = begin_authorization
    @controller = Api::Agent::OauthController.new
    @request.session[:user] = users(:perishable)

    post :approve, params: { authorization_id: authorization.id, approval_token: approval_token }

    assert_response :bad_request
    assert_equal "invalid_request", JSON.parse(@response.body)["error"]
    assert_nil authorization.reload.approved_at
  end

  test "rejects approval when the subscription becomes past due" do
    authorization, approval_token = begin_authorization(state: "expired-eligibility")
    @practice.subscription.update!(status: "past_due")

    post :approve, params: { authorization_id: authorization.id, approval_token: approval_token }

    query = redirect_query
    assert_equal "access_denied", query["error"]
    assert_equal "expired-eligibility", query["state"]
    assert_nil authorization.reload.approved_at
  end

  test "rejects an unknown approval request" do
    @request.session[:user] = @user

    post :approve, params: { authorization_id: 0, approval_token: "missing" }

    assert_response :bad_request
    assert_equal "invalid_request", JSON.parse(@response.body)["error"]
  end

  test "rejects a bad approval nonce through the registered redirect" do
    authorization, = begin_authorization(state: "preserved-state")

    post :approve, params: { authorization_id: authorization.id, approval_token: "wrong" }

    query = redirect_query
    assert_equal "access_denied", query["error"]
    assert_equal "preserved-state", query["state"]
    assert_equal @request.base_url, query["iss"]
    assert_nil authorization.reload.approved_at
  end

  test "issues a code only after approval and preserves stored state" do
    authorization, approval_token = begin_authorization(state: "original-state")

    post :approve, params: {
      authorization_id: authorization.id,
      approval_token: approval_token,
      state: "attacker-state"
    }

    query = redirect_query
    assert query["code"].present?
    assert_equal "original-state", query["state"]
    assert_equal @request.base_url, query["iss"]
    assert authorization.reload.approved_at.present?
    assert_equal AgentOauthAuthorization.digest(query["code"]), authorization.code_digest
  end

  test "rejects repeated approval" do
    authorization, approval_token = begin_authorization
    post :approve, params: { authorization_id: authorization.id, approval_token: approval_token }

    post :approve, params: { authorization_id: authorization.id, approval_token: approval_token }

    assert_equal "access_denied", redirect_query["error"]
  end

  test "exchanges an approved PKCE code for one access token" do
    verifier = VERIFIER
    code = approved_code(verifier: verifier)

    assert_difference "AgentOauthAccessToken.count", 1 do
      post :token, params: token_params(code: code, verifier: verifier)
    end

    assert_response :success
    body = JSON.parse(@response.body)
    assert_match(/\Aodonto_mcp_/, body.fetch("access_token"))
    assert_equal "Bearer", body["token_type"]
    assert_equal 1.hour.to_i, body["expires_in"]
    assert_equal "no-store", @response.headers["Cache-Control"]
    assert_equal "no-cache", @response.headers["Pragma"]

    token = AgentOauthAccessToken.last
    assert_equal "#{@request.base_url}/api/agent/mcp", token.resource
    assert token.expires_at.future?
  end

  test "rejects authorization-code replay" do
    verifier = VERIFIER
    code = approved_code(verifier: verifier)
    params = token_params(code: code, verifier: verifier)

    post :token, params: params
    assert_response :success

    assert_no_difference "AgentOauthAccessToken.count" do
      post :token, params: params
    end
    assert_response :bad_request
    assert_equal "invalid_grant", JSON.parse(@response.body)["error"]
  end

  test "rejects an incorrect PKCE verifier" do
    code = approved_code(verifier: 'c' * 43)

    post :token, params: token_params(code: code, verifier: 'w' * 43)

    assert_response :bad_request
    assert_equal "invalid_grant", JSON.parse(@response.body)["error"]
  end

  test "rejects a token request with mismatched client binding" do
    code = approved_code

    post :token, params: token_params(code: code, client_id: "https://evil.example/client.json")

    assert_response :bad_request
    assert_equal "invalid_grant", JSON.parse(@response.body)["error"]
  end

  test "rejects a token request after practice eligibility expires" do
    code = approved_code
    @practice.subscription.update!(status: "canceled")

    post :token, params: token_params(code: code)

    assert_response :bad_request
    assert_equal "invalid_grant", JSON.parse(@response.body)["error"]
  end

  test "rejects expired authorization codes" do
    authorization, approval_token = begin_authorization
    authorization.update!(expires_at: 1.minute.ago)

    post :approve, params: { authorization_id: authorization.id, approval_token: approval_token }

    assert_equal "access_denied", redirect_query["error"]
  end

  test "rejects client credentials authentication" do
    post :token, params: { grant_type: "client_credentials" }

    assert_response :bad_request
    assert_equal "unsupported_grant_type", JSON.parse(@response.body)["error"]
  end

  test 'unregistered or unsafe callbacks never receive redirects' do
    [CHATGPT_REDIRECT + '/evil', CHATGPT_REDIRECT + '#fragment', 'http://localhost/callback',
      'https://evil.example/return', ['https://evil.example/return']].each do |uri|
      get :authorize, params: authorization_params(redirect_uri: uri)
      assert_response :bad_request
      assert_nil @response.location
    end
  end

  test 'authorization enforces S256 syntax required resource and scalar state' do
    [{ code_challenge_method: 'plain' }, { code_challenge: '' }, { code_challenge: 'x' * 42 },
      { code_challenge: 'x' * 44 }, { code_challenge: ['x' * 43] }, { code_challenge: '+' * 43 },
      { resource: nil }, { resource: 'http://test.host/other' }, { resource: ['http://test.host/api/agent/mcp'] },
      { resource: 'http://test.host/api/agent/mcp#fragment' }, { state: { nested: 'value' } }].each do |invalid|
      assert_no_difference('AgentOauthAuthorization.count') { get :authorize, params: authorization_params(invalid) }
      assert_equal 'invalid_request', redirect_query['error'], invalid.inspect
    end
  end

  test 'resource normalization accepts host case and default port but not a different path' do
    @request.session[:user] = @user
    get :authorize, params: authorization_params(resource: 'http://TEST.HOST:80/api/agent/mcp')
    assert_response :success
    assert_equal 'http://test.host/api/agent/mcp', AgentOauthAuthorization.last.resource
    ['http://test.host/api/agent/mcp/', 'http://test.host/api/agent/../agent/mcp',
      'http://test.host/api/agent/%6dcp', 'http://test.host/api/agent/mcp?query=1'].each do |resource|
      get :authorize, params: authorization_params(resource: resource)
      assert_equal 'invalid_request', redirect_query['error'], resource
    end
  end

  test 'only the supported offline scope is accepted' do
    ['patients:write', ['offline_access']].each do |scope|
      get :authorize, params: authorization_params(scope: scope)
      assert_equal 'invalid_scope', redirect_query['error']
      post :token, params: { grant_type: 'refresh_token', scope: scope }
      assert_response :bad_request
      assert_equal 'invalid_scope', JSON.parse(@response.body)['error']
    end
    @request.session[:user] = @user
    get :authorize, params: authorization_params(scope: 'offline_access')
    assert_response :success
    assert AgentOauthAuthorization.last.refresh_allowed?
  end

  test 'client without refresh grant receives only an access token' do
    document = CLIENTS[:chatgpt].merge('grant_types' => ['authorization_code'])
    @test_clients[:chatgpt] = document
    get :authorize, params: authorization_params(scope: 'offline_access')
    assert_equal 'invalid_scope', redirect_query['error']
    code = approved_code
    post :token, params: token_params(code: code)
    assert_response :success
    assert_nil JSON.parse(@response.body)['refresh_token']
    assert_nil AgentOauthAccessToken.last.refresh_token_digest
  end

  test 'consent shows escaped client and callback hosts and local application warning' do
    @request.session[:user] = @user
    CLIENTS.values.each do |document|
      uri = document['redirect_uris'].first
      uri = uri.sub('localhost', 'localhost:45678') if uri.start_with?('http://localhost')
      get :authorize, params: authorization_params(client_id: document['client_id'], redirect_uri: uri)
      assert_response :success
      assert_select '.alert', text: /#{Regexp.escape(URI.parse(document['client_id']).hostname)}/
      assert_select '.alert', text: /#{Regexp.escape(URI.parse(uri).hostname)}/
      if uri.start_with?('http://localhost')
        assert_select '.alert', text: /#{Regexp.escape(I18n.t(:agent_oauth_local_warning))}/
      end
    end
    document = CLIENTS[:chatgpt].merge('client_name' => '<script>alert(1)</script>')
    @test_clients[:chatgpt] = document
    get :authorize, params: authorization_params
    assert_response :success
    assert_includes @response.body, '&lt;script&gt;alert(1)&lt;/script&gt;'
    assert_select 'h2 script', count: 0
  end

  test 'token endpoint rejects non-public authentication and does not cache errors' do
    [{ client_secret: 'secret' }, { client_assertion: 'jwt' }, { client_assertion_type: 'jwt' }].each do |authentication|
      post :token, params: { grant_type: 'authorization_code' }.merge(authentication)
      assert_response :bad_request
      assert_equal 'invalid_client', JSON.parse(@response.body)['error']
      assert_equal 'no-store', @response.headers['Cache-Control']
    end
    @request.headers['Authorization'] = 'Basic secret'
    post :token, params: { grant_type: 'authorization_code' }
    assert_equal 'invalid_client', JSON.parse(@response.body)['error']
  end

  test 'code exchange rejects missing malformed or mismatched bindings without consuming the code' do
    code = approved_code
    [{ code_verifier: nil }, { code_verifier: ['x' * 43] }, { code_verifier: 'x' * 42 },
      { code_verifier: 'x' * 129 }, { code_verifier: '/' * 43 }, { code: [] },
      { client_id: nil }, { redirect_uri: CHATGPT_REDIRECT + '/' }, { resource: nil },
      { resource: 'http://test.host/other' }].each do |invalid|
      post :token, params: token_params(code: code).merge(invalid)
      assert_response :bad_request
      assert_equal 'invalid_grant', JSON.parse(@response.body)['error'], invalid.inspect
      assert_nil AgentOauthAuthorization.last.consumed_at
    end
    post :token, params: token_params(code: code)
    assert_response :success
  end

  test 'expired approved code cannot be exchanged' do
    code = approved_code
    AgentOauthAuthorization.last.update!(expires_at: 1.second.ago)
    post :token, params: token_params(code: code)
    assert_equal 'invalid_grant', JSON.parse(@response.body)['error']
  end

  test 'refresh rotates credentials without metadata fetch and accepts omitted public client id and resource' do
    code = approved_code
    post :token, params: token_params(code: code)
    original = JSON.parse(@response.body)
    token = AgentOauthAccessToken.last
    assert_equal 'offline_access', original['scope']
    assert_equal AgentOauthAccessToken.digest(original['refresh_token']), token.refresh_token_digest
    assert_not_equal original['access_token'], token.token_digest
    assert_not_equal original['refresh_token'], token.refresh_token_digest
    travel 2.hours do
      post :token, params: { grant_type: 'refresh_token', refresh_token: original['refresh_token'] }
      assert_response :success
      fresh = JSON.parse(@response.body)
      assert_not_equal original['access_token'], fresh['access_token']
      assert_not_equal original['refresh_token'], fresh['refresh_token']
      assert token.reload.refresh_consumed_at
      assert_nil token.revoked_at
      assert_equal token.agent_oauth_authorization_id, AgentOauthAccessToken.last.agent_oauth_authorization_id
      assert AgentOauthAccessToken.last.expires_at.future?
    end
  end

  test 'refresh rejects malformed unknown expired revoked or incorrectly bound tokens' do
    post :token, params: token_params(code: approved_code)
    raw = JSON.parse(@response.body).fetch('refresh_token')
    token = AgentOauthAccessToken.last
    [{ refresh_token: nil }, { refresh_token: ['x'] }, { refresh_token: 'unknown' },
      { client_id: ['x'] }, { client_id: '' }, { client_id: 'https://wrong.example/client.json' },
      { resource: 'http://test.host/other' }, { resource: '' }].each do |invalid|
      post :token, params: { grant_type: 'refresh_token', refresh_token: raw }.merge(invalid)
      assert_equal 'invalid_grant', JSON.parse(@response.body)['error'], invalid.inspect
      assert_nil token.reload.refresh_consumed_at
    end
    token.update!(refresh_expires_at: 1.second.ago)
    post :token, params: { grant_type: 'refresh_token', refresh_token: raw }
    assert_equal 'invalid_grant', JSON.parse(@response.body)['error']
    token.update!(refresh_expires_at: 1.day.from_now, revoked_at: Time.current)
    post :token, params: { grant_type: 'refresh_token', refresh_token: raw }
    assert_equal 'invalid_grant', JSON.parse(@response.body)['error']
  end

  test 'refresh and code replay revoke every descendant but not a separate connection' do
    [:refresh, :code].each do |replay|
      post :token, params: token_params(code: approved_code)
      unrelated = AgentOauthAccessToken.last
      code = approved_code
      post :token, params: token_params(code: code)
      original = JSON.parse(@response.body)
      grant = AgentOauthAuthorization.last
      latest = original
      2.times do
        post :token, params: { grant_type: 'refresh_token', refresh_token: latest['refresh_token'],
          client_id: CHATGPT_ID, resource: 'http://test.host/api/agent/mcp', scope: 'offline_access' }
        assert_response :success
        latest = JSON.parse(@response.body)
      end
      assert_equal 3, grant.access_tokens.active.count
      request = replay == :code ? token_params(code: code) : { grant_type: 'refresh_token', refresh_token: original['refresh_token'] }
      post :token, params: request
      assert_equal 'invalid_grant', JSON.parse(@response.body)['error']
      assert grant.access_tokens.all?(&:revoked_at?)
      assert_nil unrelated.reload.revoked_at
      post :token, params: { grant_type: 'refresh_token', refresh_token: latest['refresh_token'] }
      assert_equal 'invalid_grant', JSON.parse(@response.body)['error']
    end
  end

  test 'disabling and reenabling practice does not resurrect refresh tokens with expired access tokens' do
    post :token, params: token_params(code: approved_code)
    raw = JSON.parse(@response.body)['refresh_token']
    travel 2.hours do
      @practice.update!(agent_access_enabled: false)
      @practice.update!(agent_access_enabled: true)
      assert AgentOauthAccessToken.last.revoked_at
      post :token, params: { grant_type: 'refresh_token', refresh_token: raw }
      assert_equal 'invalid_grant', JSON.parse(@response.body)['error']
    end
  end

  test 'regular users can authorize and exchange their own connection' do
    @user = users(:perishable)
    code = approved_code
    post :token, params: token_params(code: code)
    assert_response :success
    token = AgentOauthAccessToken.find_by!(token_digest: AgentOauthAccessToken.digest(JSON.parse(response.body).fetch('access_token')))
    assert_equal @user, token.user
    assert_equal @practice, token.practice
  end

  private

  def enable_agent_access
    unless UserConsent.accepted?(@user, "ai_data_processing")
      UserConsent.create!(
        user: @user,
        practice: @practice,
        consent_type: "ai_data_processing",
        policy_version: UserConsent::CURRENT_AI_VERSION,
        accepted_at: Time.current
      )
    end
    @practice.update!(agent_access_enabled: true)
  end

  def begin_authorization(verifier: VERIFIER, state: nil)
    challenge = Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false)
    @request.session[:user] = @user
    get :authorize, params: authorization_params(code_challenge: challenge, state: state)

    authorization = AgentOauthAuthorization.order(:created_at).last
    approval_token = @response.body.match(/name="approval_token"[^>]*value="([^"]+)"/)[1]
    [authorization, approval_token]
  end

  def approved_code(verifier: VERIFIER)
    authorization, approval_token = begin_authorization(verifier: verifier)
    post :approve, params: { authorization_id: authorization.id, approval_token: approval_token }
    redirect_query.fetch("code")
  end

  def authorization_params(overrides = {})
    {
      response_type: "code",
      client_id: CHATGPT_ID,
      redirect_uri: CHATGPT_REDIRECT,
      code_challenge: Base64.urlsafe_encode64(Digest::SHA256.digest(VERIFIER), padding: false),
      code_challenge_method: "S256",
      resource: "#{@request.base_url}/api/agent/mcp"
    }.merge(overrides)
  end

  def token_params(code:, verifier: VERIFIER, client_id: CHATGPT_ID)
    authorization_params(
      grant_type: "authorization_code",
      code: code,
      code_verifier: verifier,
      client_id: client_id
    )
  end

  def redirect_query
    URI.decode_www_form(URI.parse(@response.location).query.to_s).to_h
  end
end
