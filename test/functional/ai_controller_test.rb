# frozen_string_literal: true

require 'test_helper'

class AiControllerTest < ActionController::TestCase
  setup do
    @practice = practices(:complete)
    @controller.session['user'] = users(:founder)
  end

  teardown do
    I18n.locale = I18n.default_locale
  end

  test 'AI is a dedicated section and legacy settings routes remain available' do
    assert_routing '/ai', controller: 'ai', action: 'show'
    assert_recognizes({ controller: 'ai', action: 'show' }, '/practice/agent-settings')
    assert_recognizes({ controller: 'ai', action: 'update' }, { path: '/practice/agent-settings', method: :patch })
    get :show
    assert_response :success
    assert_select "a.nav-link[href='/ai'][aria-current='page'] .nav-link-title", text: "AI"
    assert_select "input[name='practice[agent_access_enabled]'][type=checkbox]", count: 1
    assert_select "input[name='practice[agent_label]']", count: 0
  end

  test 'regular users can open AI and get actionable disabled guidance without admin controls' do
    @controller.session['user'] = users(:perishable)
    get :show
    assert_response :success
    assert_select '[data-ai-unavailable]', text: /administrator/
    assert_select "form[action='/ai']", count: 0
    assert_select '#ai-practice-settings', count: 0
    assert_select '#agent-url-input', count: 0
    assert_select "a[href='/practice/settings']", count: 0
  end

  test 'enabled AI shows a minimal connection path in every locale' do
    enable_ai
    @controller.session['user'] = users(:perishable)
    %w[en es pt].each do |locale|
      @practice.update!(locale: locale)
      get :show
      assert_response :success
      assert_select '.translation_missing', count: 0
      assert_select "label[for='agent-url-input']", count: 1
      assert_select "input#agent-url-input[readonly][value='http://test.host/api/agent/mcp']", count: 1
      assert_select 'button[data-ai-copy]', count: 1
      assert_select '[data-ai-copy-status][role=status]', count: 1
      assert_select '#ai-get-started', count: 1
      assert_select '#ai-claude', count: 1
      assert_select '#ai-chatgpt', count: 1
      assert_select '#ai-get-started .nav-tabs', count: 0
      assert_select '#ai-examples', count: 0
      assert_select '#ai-overview-title', count: 0
      assert_select "form[action='/ai']", count: 0
    end
  end

  test 'an enabled but ineligible practice cannot be presented as ready to connect' do
    enable_ai
    @practice.subscription.update!(status: 'past_due')
    get :show
    assert_response :success
    assert_select '[data-ai-unavailable]', count: 1
    assert_select '#agent-url-input', count: 0
    assert_select "a[href='/practice/settings']"
  end

  test 'regular users cannot enable or disable AI using either route' do
    @controller.session['user'] = users(:perishable)
    [false, true].each do |enabled|
      @practice.update!(agent_access_enabled: enabled)
      assert_no_difference 'UserConsent.count' do
        patch :update, params: { practice: { agent_access_enabled: enabled ? '0' : '1', agent_label: 'Changed' }, consent_ai: '1' }
      end
      assert_response :redirect
      assert_equal enabled, @practice.reload.agent_access_enabled?
      assert_equal 'Agent', @practice.agent_label
    end
  end

  test 'admins must consent before enabling AI and errors preserve the page' do
    patch :update, params: { practice: { agent_access_enabled: '1' } }
    assert_response :success
    assert_not @practice.reload.agent_access_enabled?
    assert_select "input[name='consent_ai']"
    assert_includes response.body, I18n.t(:consent_ai_required)

    patch :update, params: { practice: { agent_access_enabled: '1' }, consent_ai: '1' }
    assert_redirected_to ai_path
    assert @practice.reload.agent_access_eligible?
    assert UserConsent.accepted?(users(:founder), 'ai_data_processing')
  end

  test 'admin disable revokes existing credentials and reenable does not restore them' do
    enable_ai
    token = AgentOauthAccessToken.create!(user: users(:perishable), practice: @practice,
      token_digest: AgentOauthAccessToken.digest('existing'), resource: 'http://test.host/api/agent/mcp',
      expires_at: 1.hour.from_now, refresh_token_digest: AgentOauthAccessToken.digest('refresh'),
      refresh_expires_at: 1.day.from_now)
    patch :update, params: { practice: { agent_access_enabled: '0' } }
    assert_redirected_to ai_path
    assert_not @practice.reload.agent_access_enabled?
    assert token.reload.revoked_at
    patch :update, params: { practice: { agent_access_enabled: '1' } }
    assert @practice.reload.agent_access_eligible?
    assert token.reload.revoked_at
  end

  test 'signed out users cannot view or change AI' do
    @controller.session['user'] = nil
    get :show
    assert_redirected_to signin_path
    patch :update, params: { practice: { agent_access_enabled: '1' }, consent_ai: '1' }
    assert_redirected_to signin_path
    assert_not @practice.reload.agent_access_enabled?
  end

  test 'setup shows both providers without tabs and places administration in the right column' do
    enable_ai
    get :show
    assert_select '#ai-get-started .nav-tabs', count: 0
    assert_select '#ai-get-started #ai-claude', text: /Claude/
    assert_select '#ai-get-started #ai-chatgpt', text: /ChatGPT/
    assert_select '#ai-get-started button[data-ai-copy].btn', count: 1
    assert_select '#ai-get-started button[data-ai-copy].btn-primary', count: 0
    assert_select "#ai-chatgpt a[href='https://learn.chatgpt.com/docs/plugins'].btn", count: 0
    assert_select '#ai-examples', count: 0
    assert_select '#ai-get-started #ai-practice-settings', count: 0
    assert_select '.row-cards > .col-md-4 #ai-practice-settings.card', count: 1
    assert_select '#ai-practice-settings .card-title .icon-tabler-robot-face', count: 1
    assert_select '#ai-practice-settings form[data-ai-access-form]', count: 1
    assert_select '#ai-practice-settings input[data-ai-access-toggle]', count: 1
    assert_select '#ai-practice-settings input[type=submit]', count: 0
  end

  test 'regular users see both provider paths together' do
    enable_ai
    @controller.session['user'] = users(:perishable)
    %w[en es pt].each do |locale|
      @practice.update!(locale: locale)
      get :show
      assert_response :success
      assert_select '#ai-claude #agent-url-input', count: 1
      assert_select '#ai-chatgpt', count: 1
      assert_select "#ai-chatgpt a[href='https://learn.chatgpt.com/docs/plugins'][rel='noopener']", count: 1
      assert_select "#ai-chatgpt a[href='https://learn.chatgpt.com/docs/plugins'].btn", count: 0
      assert_select "form[action='/ai']", count: 0
      assert_select '#ai-practice-settings', count: 0
      assert_select '.translation_missing', count: 0
    end
  end

  test 'saving practice settings preserves the chosen app' do
    enable_ai
    patch :update, params: { app: 'chatgpt', practice: { agent_access_enabled: '1' } }
    assert_redirected_to ai_path(app: 'chatgpt')
  end

  test 'app query choices do not hide either provider' do
    enable_ai
    get :show, params: { app: 'unknown' }
    assert_response :success
    assert_select '#ai-claude #agent-url-input', count: 1
    assert_select '#ai-chatgpt', count: 1
  end

  test 'practice controls and consent errors remain visible when AI is disabled' do
    get :show
    assert_select '#ai-practice-settings.card input[type=checkbox]', count: 2
    patch :update, params: { practice: { agent_access_enabled: '1' } }
    assert_select '#ai-practice-settings .alert[role=alert]', count: 1
    assert_select '#ai-practice-settings input[name=consent_ai]', count: 1
  end

  private

  def enable_ai
    UserConsent.create!(user: users(:founder), practice: @practice, consent_type: 'ai_data_processing',
      policy_version: UserConsent::CURRENT_AI_VERSION, accepted_at: Time.current)
    @practice.update!(agent_access_enabled: true)
  end
end
