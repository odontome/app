# frozen_string_literal: true

require 'test_helper'

class OdontogramReleaseTest < ActionDispatch::IntegrationTest
  setup do
    Announcements.reload!
    post user_session_path, params: { signin: { email: users(:founder).email, password: '1234567890' } }
    assert_response :redirect
  end

  teardown do
    I18n.locale = I18n.default_locale
  end

  test 'patient profiles and empty charts are available regardless of former pilot access' do
    [false, true].each do |enabled|
      practices(:complete).update!(odontogram_enabled: enabled)

      get patient_path(patients(:one))
      assert_response :success
      assert_select '[data-odontogram][data-odontogram-session-enabled="true"]', count: 1
      assert_select 'a[href=?]', patient_odontogram_path(patients(:one))

      get patient_odontogram_path(patients(:one)), as: :json
      assert_response :success
      assert_equal true, response.parsed_body.fetch('editable')
      assert_equal [], response.parsed_body.fetch('entries')

      get report_patient_odontogram_path(patients(:one))
      assert_response :success
    end
  end

  test 'launch announcement is localized actionable and stays dismissed after navigation' do
    titles = { 'en' => 'Odontograms are here!', 'es' => '¡Ya puedes usar los odontogramas!', 'pt' => 'Os odontogramas chegaram!' }
    titles.each do |locale, title|
      practices(:complete).update!(locale: locale)
      get patient_path(patients(:one))
      assert_response :success
      assert_select '[data-announcement-version="2"].announcement-alert' do
        assert_select 'strong', text: title
        assert_select 'a[href=?]', patients_path
        assert_select 'a[href^="mailto:hello@odonto.me"]'
        assert_select '[data-announcement-dismiss][aria-label=?]', I18n.t('announcements.dismiss', locale: locale)
      end
      assert_no_match(/translation_missing|Translation missing/, response.body)
    end

    post dismiss_announcement_path, params: { version: 2 }, as: :json
    assert_response :success
    get patients_path
    assert_response :success
    assert_select '[data-announcement-version="2"]', count: 0
    get patient_path(patients(:one))
    assert_select '[data-announcement-version="2"]', count: 0
  end

  test 'retired admin pilot endpoint is no longer routable' do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path('/admin/practices/1/odontogram', method: :patch)
    end
  end
end
