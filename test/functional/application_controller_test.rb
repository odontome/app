# frozen_string_literal: true

require 'test_helper'

class ApplicationControllerTest < ActionController::TestCase
  tests PatientsController

  setup do
    @controller.session['user'] = users(:founder)
  end

  test 'shows expiring subscription warning banner on authenticated pages' do
    users(:founder).practice.subscription.update_columns(current_period_end: 6.days.from_now)
    expected_warning = I18n.t('subscriptions.errors.expiring', practice_settings_url: practice_settings_url)

    get :index

    assert_response :success
    assert_equal expected_warning, flash[:warning].to_s
    assert_select '.alert.alert-warning .text-muted', text: /Your subscription will expire soon/
    assert_includes response.body, expected_warning
  end
end
