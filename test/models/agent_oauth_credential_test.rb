# frozen_string_literal: true

require 'test_helper'

class AgentOauthCredentialTest < ActiveSupport::TestCase
  setup do
    @practice = practices(:complete)
    @user = users(:perishable)
    @practice.update!(agent_access_enabled: true)
  end

  test 'practice eligibility requires an enabled active subscription and AI consent' do
    assert_not @practice.agent_access_eligible?

    create_ai_consent(@user)
    assert @practice.agent_access_eligible?

    @practice.subscription.update!(status: 'canceled')
    assert_not @practice.agent_access_eligible?
  end

  test 'expired trials are not eligible for agent access' do
    create_ai_consent(@user)
    @practice.subscription.update!(status: 'trialing', current_period_end: 1.day.ago)

    assert_not @practice.agent_access_eligible?
  end

  test 'cancelled practices are not eligible for agent access' do
    create_ai_consent(@user)
    @practice.update!(cancelled_at: Time.current)

    assert_not @practice.agent_access_eligible?
  end

  test 'disabling agent access revokes tokens and removes pending authorizations' do
    create_ai_consent(@user)
    authorization = create_authorization
    token = create_access_token

    @practice.update!(agent_access_enabled: false)

    assert token.reload.revoked_at.present?
    assert_not AgentOauthAuthorization.exists?(authorization.id)
  end

  test 'cancelling a practice revokes tokens and removes pending authorizations' do
    create_ai_consent(@user)
    authorization = create_authorization
    token = create_access_token

    @practice.update!(cancelled_at: Time.current)

    assert token.reload.revoked_at.present?
    assert_not AgentOauthAuthorization.exists?(authorization.id)
  end

  test 'deleting a user cascades OAuth credentials' do
    authorization = create_authorization
    token = create_access_token

    @user.destroy!

    assert_not AgentOauthAuthorization.exists?(authorization.id)
    assert_not AgentOauthAccessToken.exists?(token.id)
  end

  test 'deleting a practice cascades OAuth credentials' do
    authorization = create_authorization
    token = create_access_token

    @practice.destroy!

    assert_not AgentOauthAuthorization.exists?(authorization.id)
    assert_not AgentOauthAccessToken.exists?(token.id)
  end

  private

  def create_ai_consent(user)
    UserConsent.create!(
      user: user,
      practice: @practice,
      consent_type: 'ai_data_processing',
      policy_version: UserConsent::CURRENT_AI_VERSION,
      accepted_at: Time.current
    )
  end

  def create_authorization
    AgentOauthAuthorization.create!(
      user: @user,
      practice: @practice,
      approval_token_digest: AgentOauthAuthorization.digest(SecureRandom.hex(24)),
      client_id: Api::Agent::OauthController::CHATGPT_CLIENT_ID,
      redirect_uri: Api::Agent::OauthController::CHATGPT_REDIRECT_URI,
      code_challenge: 'challenge',
      resource: 'https://my.odonto.me/api/agent/mcp',
      expires_at: 5.minutes.from_now
    )
  end

  def create_access_token
    AgentOauthAccessToken.create!(
      user: @user,
      practice: @practice,
      token_digest: AgentOauthAccessToken.digest(SecureRandom.hex(24)),
      resource: 'https://my.odonto.me/api/agent/mcp',
      expires_at: 1.hour.from_now
    )
  end
end
