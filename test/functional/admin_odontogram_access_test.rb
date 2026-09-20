# frozen_string_literal: true

require 'test_helper'

class AdminOdontogramAccessTest < ActionController::TestCase
  tests AdminController

  setup do
    @controller.session['user'] = users(:superadmin)
  end

  teardown do
    I18n.locale = I18n.default_locale
  end

  test 'practice list no longer offers pilot controls in any locale' do
    %w[en es pt].each do |locale|
      practices(:complete).update!(locale: locale)
      get :practices

      assert_response :success
      assert_select "form[action$='/odontogram']", count: 0
      assert_select "input[name='practice[odontogram_enabled]']", count: 0
      assert_select '.translation_missing', count: 0
    end
  end
end
