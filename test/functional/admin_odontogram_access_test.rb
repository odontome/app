# frozen_string_literal: true

require 'test_helper'

class AdminOdontogramAccessTest < ActionController::TestCase
  tests AdminController

  setup do
    @controller.session['user'] = users(:superadmin)
    @practice = practices(:complete_another_language)
  end

  teardown do
    I18n.locale = I18n.default_locale
  end

  test 'superadmin can enable and disable exactly the requested practice' do
    other_flags = Practice.where.not(id: @practice.id).pluck(:id, :odontogram_enabled)

    %w[1 0 1].each do |value|
      patch :update_odontogram_access, params: { id: @practice.id, practice: { odontogram_enabled: value } }

      assert_redirected_to practices_admin_path
      assert_equal value == '1', @practice.reload.odontogram_enabled?
      assert_equal other_flags, Practice.where.not(id: @practice.id).pluck(:id, :odontogram_enabled)
    end
  end

  test 'toggle records its actor time and exact change' do
    previous_enabled = PaperTrail.enabled?
    PaperTrail.enabled = true

    travel_to Time.utc(2026, 9, 9, 12) do
      assert_difference -> { @practice.versions.count }, 1 do
        patch :update_odontogram_access, params: { id: @practice.id, practice: { odontogram_enabled: '1' } }
      end

      version = @practice.versions.last
      assert_equal users(:superadmin).id.to_s, version.whodunnit
      assert_equal Time.current, version.created_at
      assert_equal [false, true], version.changeset['odontogram_enabled']
      assert_equal @practice.id, version.practice_id
    end
  ensure
    PaperTrail.enabled = previous_enabled
  end

  test 'toggle cannot modify other practice attributes' do
    old_name = @practice.name
    patch :update_odontogram_access, params: {
      id: @practice.id, practice: { odontogram_enabled: '1', name: 'Unexpected change', agent_access_enabled: '1' }
    }

    assert @practice.reload.odontogram_enabled?
    assert_equal old_name, @practice.name
    assert_not @practice.agent_access_enabled?
  end

  [nil, :founder, :perishable, :user_in_yet_another_practice].each do |actor|
    test "#{actor || 'signed out visitor'} cannot toggle a practice" do
      @controller.session['user'] = actor && users(actor)
      patch :update_odontogram_access, params: { id: @practice.id, practice: { odontogram_enabled: '1' } }

      assert_response :redirect
      assert_not @practice.reload.odontogram_enabled?
    end
  end

  test 'a genuine impersonation session cannot toggle even with a superadmin target user' do
    users(:founder).update_columns(roles: 'superadmin')
    @controller.session['user'] = users(:founder)
    @controller.session['impersonator_id'] = users(:superadmin).id
    patch :update_odontogram_access, params: { id: @practice.id, practice: { odontogram_enabled: '1' } }

    assert_response :redirect
    assert_not @practice.reload.odontogram_enabled?
  end

  test 'malformed toggle values are rejected instead of enabling access' do
    ['yes', '', '2', nil, []].each do |value|
      patch :update_odontogram_access, params: { id: @practice.id, practice: { odontogram_enabled: value } }
      assert_response :bad_request
      assert_not @practice.reload.odontogram_enabled?
    end
  end

  test 'practice list has localized accessible pilot controls' do
    expected = { 'en' => 'Enable odontograms', 'es' => 'Activar odontogramas', 'pt' => 'Ativar odontogramas' }
    expected.each do |locale, text|
      practices(:complete).update!(locale: locale)
      get :practices

      assert_response :success
      assert_select "form[action='#{admin_practice_odontogram_path(@practice)}']" do
        assert_select 'button', text: text
        assert_select "input[name='practice[odontogram_enabled]'][value='1']"
      end
      assert_select '.translation_missing', count: 0
    end
  end

  test 'enabled practice control offers an explicit disable action' do
    @practice.update!(odontogram_enabled: true)
    get :practices

    assert_select "form[action='#{admin_practice_odontogram_path(@practice)}']" do
      assert_select 'button', text: 'Disable odontograms'
      assert_select "input[name='practice[odontogram_enabled]'][value='0']"
    end
  end

  test 'impersonation view does not show pilot controls' do
    @controller.session['user'] = users(:founder)
    @controller.session['impersonator_id'] = users(:superadmin).id
    get :practices

    assert_response :success
    assert_select "form[action$='/odontogram']", count: 0
  end
end
