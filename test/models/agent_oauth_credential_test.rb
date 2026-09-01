# frozen_string_literal: true

require 'test_helper'

class AgentOauthCredentialTest < ActiveSupport::TestCase
  include AgentOauthTestClients
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

  test 'past due subscriptions are not eligible for agent access' do
    create_ai_consent(@user)
    @practice.subscription.update!(status: 'past_due')

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

  test 'credential operations fail closed when records disappear during locking' do
    create_ai_consent(@user)
    authorization = create_authorization
    practice = authorization.practice
    practice.stub(:with_lock, ->(*) { raise ActiveRecord::RecordNotFound }) do
      assert_nil authorization.approve('approval')
      assert_nil authorization.exchange(client_id: authorization.client_id, redirect_uri: authorization.redirect_uri,
        resource: authorization.resource, code_verifier: 'v' * 43)
    end

    token = create_access_token
    practice = token.practice
    practice.stub(:with_lock, ->(*) { raise ActiveRecord::RecordNotFound }) do
      assert_nil token.refresh(client_id: nil, resource: token.resource)
    end
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
      client_id: CHATGPT_ID,
      redirect_uri: CHATGPT_REDIRECT,
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
