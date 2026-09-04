# frozen_string_literal: true

require 'test_helper'

class AuditsControllerTest < ActionController::TestCase
  setup do
    @controller.session['user'] = users(:founder)
    @user = users(:perishable)
    @ai_version = PaperTrail::Version.create!(item: appointments(:first_visit), event: 'update',
      practice_id: @user.practice_id, whodunnit: @user.id.to_s, activity_source: 'ai')
    @web_version = PaperTrail::Version.create!(item: appointments(:first_visit), event: 'update',
      practice_id: @user.practice_id, whodunnit: @user.id.to_s)
    @legacy_version = PaperTrail::Version.create!(item: appointments(:first_visit), event: 'update',
      practice_id: @user.practice_id, whodunnit: 'agent:Old assistant')
  end

  test 'user filter includes both AI and web changes with an AI marker only for AI changes' do
    get :index, params: { user_id: @user.id }
    assert_response :success
    assert_equal [@ai_version.id, @web_version.id].sort, assigns(:versions).map(&:id).sort
    assert_select '[data-activity-source=ai]', text: "(#{I18n.t('ai.via_ai')})", count: 1
    assert_select '[data-activity-source=ai].badge', count: 0
    assert_select 'td', text: /#{Regexp.escape(@user.fullname)}/, count: 2
    assert_select 'option[value="agent:Old assistant"]'
  end

  test 'details show the user and AI source while legacy agent history remains readable' do
    get :show, params: { id: @ai_version.id }
    assert_response :success
    assert_includes response.body, @user.fullname
    assert_select '[data-activity-source=ai]', text: "(#{I18n.t('ai.via_ai')})"
    assert_select '[data-activity-source=ai].badge', count: 0
    get :show, params: { id: @legacy_version.id }
    assert_response :success
    assert_includes response.body, I18n.t(:agent_display_name, label: 'Old assistant')
    assert_select '[data-activity-source=ai]', count: 0
  end

  test 'audit details cannot load a version from another practice' do
    @ai_version.update!(practice_id: users(:user_in_yet_another_practice).practice_id)
    assert_raises ActiveRecord::RecordNotFound do
      get :show, params: { id: @ai_version.id }
    end
  end
end
