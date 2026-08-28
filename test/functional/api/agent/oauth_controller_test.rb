# frozen_string_literal: true

require "test_helper"

class Api::Agent::OauthControllerTest < ActionController::TestCase
  setup do
    @practice = practices(:complete)
    @user = users(:founder)
    enable_agent_access
    @controller = Api::Agent::OauthController.new
    @routes = Rails.application.routes
  end

  test "publishes protected-resource metadata" do
    get :protected_resource_metadata

    body = JSON.parse(@response.body)
    assert_equal "#{@request.base_url}/api/agent/mcp", body["resource"]
    assert_equal [@request.base_url], body["authorization_servers"]
    assert_equal [], body["scopes_supported"]
  end

  test "publishes ChatGPT OAuth metadata" do
    get :authorization_server_metadata

    body = JSON.parse(@response.body)
    assert_equal @request.base_url, body["issuer"]
    assert_equal ["authorization_code"], body["grant_types_supported"]
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

  test "rejects authorization requests from unknown clients without redirecting" do
    get :authorize, params: authorization_params(client_id: "https://evil.example/client.json")

    assert_response :bad_request
    assert_equal "invalid_request", JSON.parse(@response.body)["error"]
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
    verifier = "test-verifier"
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
    verifier = "test-verifier"
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
    code = approved_code(verifier: "correct-verifier")

    post :token, params: token_params(code: code, verifier: "wrong-verifier")

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

  def begin_authorization(verifier: "test-verifier", state: nil)
    challenge = Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false)
    @request.session[:user] = @user
    get :authorize, params: authorization_params(code_challenge: challenge, state: state)

    authorization = AgentOauthAuthorization.order(:created_at).last
    approval_token = @response.body.match(/name="approval_token"[^>]*value="([^"]+)"/)[1]
    [authorization, approval_token]
  end

  def approved_code(verifier: "test-verifier")
    authorization, approval_token = begin_authorization(verifier: verifier)
    post :approve, params: { authorization_id: authorization.id, approval_token: approval_token }
    redirect_query.fetch("code")
  end

  def authorization_params(overrides = {})
    {
      response_type: "code",
      client_id: Api::Agent::OauthController::CHATGPT_CLIENT_ID,
      redirect_uri: Api::Agent::OauthController::CHATGPT_REDIRECT_URI,
      code_challenge: "challenge",
      code_challenge_method: "S256",
      resource: "#{@request.base_url}/api/agent/mcp"
    }.merge(overrides.compact)
  end

  def token_params(code:, verifier: "test-verifier", client_id: Api::Agent::OauthController::CHATGPT_CLIENT_ID)
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
