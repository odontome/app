# frozen_string_literal: true

require 'test_helper'

class WelcomeControllerTest < ActionController::TestCase
  teardown do
    I18n.locale = I18n.default_locale
  end

  test 'redirects unauthenticated visitors to sign in' do
    @controller.session['user'] = nil

    get :index

    assert_redirected_to signin_path
  end

  test 'admin of a practice with no doctors is redirected to the practice checklist' do
    practices(:complete).update_columns(doctors_count: 0, patients_count: 5)
    @controller.session['user'] = users(:founder)

    get :index

    assert_redirected_to practice_path
  end

  test 'admin of a practice with no patients is redirected to the practice checklist' do
    practices(:complete).update_columns(doctors_count: 2, patients_count: 0)
    @controller.session['user'] = users(:founder)

    get :index

    assert_redirected_to practice_path
  end

  test 'admin of a fully set up practice keeps the existing datebook redirect' do
    practices(:complete).update_columns(doctors_count: 2, patients_count: 3)
    @controller.session['user'] = users(:founder)

    get :index

    assert_redirected_to datebook_path(datebooks(:playa_del_carmen))
  end

  test 'non-admin user is unaffected by the practice checklist redirect' do
    practices(:complete).update_columns(doctors_count: 0, patients_count: 0)
    @controller.session['user'] = users(:perishable)

    get :index

    assert_redirected_to datebook_path(datebooks(:playa_del_carmen))
  end

  test 'superadmin is still sent to the practices admin index regardless of practice setup' do
    practices(:complete).update_columns(doctors_count: 0, patients_count: 0)
    @controller.session['user'] = users(:superadmin)

    get :index

    assert_redirected_to practices_admin_path
  end
end
