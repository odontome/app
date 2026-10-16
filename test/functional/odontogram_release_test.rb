# frozen_string_literal: true

require 'test_helper'

class OdontogramReleaseTest < ActionDispatch::IntegrationTest
  setup do
    post user_session_path, params: { signin: { email: users(:founder).email, password: '1234567890' } }
    assert_response :redirect
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

  test 'retired admin pilot endpoint is no longer routable' do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path('/admin/practices/1/odontogram', method: :patch)
    end
  end
end
