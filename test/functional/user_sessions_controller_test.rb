# frozen_string_literal: true

require 'test_helper'

class UserSessionsControllerTest < ActionController::TestCase
  test 'should get new' do
    get :new
    assert_response :success
  end

  test 'should create user session if valid params are given' do
    post :create, params: { signin: { email: users(:founder).email, password: '1234567890' } }

    assert_equal @controller.session['user'], users(:founder)
    assert_redirected_to root_url
  end

  test 'should update the last and current session dates after a successful login' do
    current_user = users(:founder)
    old_current_login_at = current_user.current_login_at

    today = Time.current
    
    freeze_time do
      post :create, params: { signin: { email: current_user.email, password: '1234567890' } }
    end
    
    # reload the model from the database
    current_user.reload
    
    assert_equal current_user.current_login_at.beginning_of_day, today.beginning_of_day
    assert_equal current_user.last_login_at, old_current_login_at
  end

  test 'should show login screen if email is not found' do
    post :create, params: { signin: { email: 'not-a-user@email.com', password: '1234567890' } }

    assert_nil @controller.session['user']
    assert_response :success
    assert_template :new
  end

  test 'should request user to reset password if not migrated' do
    non_migrated_user = users(:non_migrated_user)
    post :create, params: { signin: { email: non_migrated_user.email, password: '1234567890' } }

    assert_nil @controller.session['user']
    assert_redirected_to new_password_reset_url
  end
end
