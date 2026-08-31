# frozen_string_literal: true

require 'test_helper'

class AgentOauthConcurrencyTest < ActiveSupport::TestCase
  include AgentOauthTestClients
  self.use_transactional_tests = false

  setup do
    @practice = practices(:complete)
    @user = users(:perishable)
    @practice.update!(agent_access_enabled: true)
    UserConsent.where(user: @user, consent_type: 'ai_data_processing').delete_all
    UserConsent.create!(user: @user, practice: @practice, consent_type: 'ai_data_processing',
      policy_version: UserConsent::CURRENT_AI_VERSION, accepted_at: Time.current)
    @authorization = AgentOauthAuthorization.create!(user: @user, practice: @practice,
      approval_token_digest: AgentOauthAuthorization.digest('approval'), client_id: CHATGPT_ID,
      redirect_uri: CHATGPT_REDIRECT, code_challenge: 'challenge', resource: 'https://my.odonto.me/api/agent/mcp',
      refresh_allowed: true, approved_at: Time.current, consumed_at: Time.current, expires_at: 5.minutes.from_now)
    @response = nil
    @practice.with_lock { @response = AgentOauthAccessToken.issue!(@authorization) }
    @token = AgentOauthAccessToken.last
  end

  teardown do
    AgentOauthAccessToken.where(practice: @practice).delete_all
    AgentOauthAuthorization.where(practice: @practice).delete_all
    UserConsent.where(user: @user, consent_type: 'ai_data_processing').delete_all
    @practice.update_columns(agent_access_enabled: false)
  end

  test 'simultaneous refresh rotates once then detects replay and revokes the family' do
    ready = Queue.new
    start = Queue.new
    results = Queue.new
    threads = 2.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ready << true
          start.pop
          result = AgentOauthAccessToken.find(@token.id).refresh(client_id: nil, resource: @token.resource)
          results << result
        end
      end
    end
    2.times { ready.pop }
    2.times { start << true }
    threads.each { |thread| thread.join(5) || flunk('refresh worker deadlocked') }

    values = 2.times.map { results.pop }
    assert_equal 1, values.compact.size
    assert values.compact.first[:refresh_token]
    assert @authorization.reload.access_tokens.none? { |token| token.revoked_at.nil? }
  end

  test 'practice revocation and refresh share the same lock so credentials cannot survive disablement' do
    practice_locked = Queue.new
    release = Queue.new
    result = Queue.new
    disabler = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        practice = Practice.find(@practice.id)
        practice.with_lock do
          practice.agent_access_enabled = false
          practice_locked << true
          release.pop
          practice.save!
        end
      end
    end
    practice_locked.pop
    refresher = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        result << AgentOauthAccessToken.find(@token.id).refresh(client_id: nil, resource: @token.resource)
      end
    end
    release << true
    [disabler, refresher].each { |thread| thread.join(5) || flunk('credential worker deadlocked') }

    assert_nil result.pop
    assert @token.reload.revoked_at
    assert_equal 1, @authorization.reload.access_tokens.count
  end
end
