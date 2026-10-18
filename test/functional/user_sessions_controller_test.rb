# frozen_string_literal: true

require 'test_helper'

class UserSessionsControllerTest < ActionController::TestCase
  test 'should get new' do
    get :new
    assert_response :success
  end

  test 'should redirect show to root when signed in' do
    @controller.session['user'] = users(:founder)
    get :show

    assert_redirected_to root_url
  end

  test 'should redirect show to signin when signed out' do
    get :show

    assert_redirected_to signin_path
  end

  test 'should not route to edit or update' do
    assert_raises(ActionController::UrlGenerationError) { get :edit }
    assert_raises(ActionController::UrlGenerationError) { patch :update }
  end

  test 'should create user session if valid params are given' do
    post :create, params: { signin: { email: users(:founder).email, password: '1234567890' } }

    assert_equal users(:founder).id, @controller.session['user']['id']
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

  test 'should create persistent login when remember me is checked' do
    post :create, params: { signin: { email: users(:founder).email, password: '1234567890', remember_me: '1' } }

    assert_equal users(:founder).id, @controller.session['user']['id']
    assert_redirected_to root_url
    
    # Check that remember token was set
    users(:founder).reload
    assert users(:founder).remember_token_digest.present?
    assert users(:founder).remember_token_expires_at.present?
    assert users(:founder).remember_token_valid?
    
    # Check that cookie was set
    assert @response.cookies['remember_token'].present?
  end

  test 'should not create persistent login when remember me is not checked' do
    post :create, params: { signin: { email: users(:founder).email, password: '1234567890', remember_me: '0' } }

    assert_equal users(:founder).id, @controller.session['user']['id']
    assert_redirected_to root_url
    
    # Check that remember token was not set
    users(:founder).reload
    assert users(:founder).remember_token_digest.blank?
    assert users(:founder).remember_token_expires_at.blank?
    
    # Check that cookie was not set
    assert @response.cookies['remember_token'].blank?
  end

  test 'should clear remember token on logout' do
    user = users(:founder)
    user.remember_me!
    @controller.session[:user] = user

    delete :destroy

    user.reload
    assert user.remember_token_digest.blank?
    assert user.remember_token_expires_at.blank?
    assert_redirected_to root_url
  end

  test 'should redirect back to signin with a friendly message when the CSRF token is stale' do
    ActionController::Base.allow_forgery_protection = true
    post :create, params: { signin: { email: users(:founder).email, password: '1234567890' } }

    assert_nil @controller.session['user']
    assert_redirected_to signin_path
    assert_equal I18n.t(:stale_page_message), flash[:alert]
  ensure
    ActionController::Base.allow_forgery_protection = false
  end

  test 'should handle login with expired remember token gracefully' do
    user = users(:founder)
    user.update_columns(remember_token_digest: User.digest_remember_token('expired_token'),
                        remember_token_expires_at: 1.day.ago)
    
    # Simulate having an expired remember token cookie
    @request.cookies[:remember_token] = 'expired_token'
    
    get :new
    
    # Should not be logged in with expired token
    assert_nil @controller.session['user']
    assert_response :success
  end

  test 'login replaces the session but keeps where the user was going' do
    @request.session[:planted_by_someone_else] = 'fixation'
    @request.session[:return_to] = 'http://test.host/patients'

    post :create, params: { signin: { email: users(:founder).email, password: '1234567890' } }

    assert_redirected_to 'http://test.host/patients'
    assert_nil @controller.session[:planted_by_someone_else]
    assert_nil @controller.session[:return_to]
    assert_equal users(:founder).id, @controller.session['user']['id']
  end

  test 'login stores only the id and current session token' do
    user = users(:founder)
    user.update_columns(session_token: 'existing-token')

    post :create, params: { signin: { email: user.email, password: '1234567890' } }

    assert_equal({ 'id' => user.id, 'session_token' => 'existing-token' }, @controller.session['user'])
    # Signing in on another device must not sign the user out elsewhere
    assert_equal 'existing-token', user.reload.session_token
  end

  test 'login gives a token to users who do not have one yet' do
    user = users(:founder)
    user.update_columns(session_token: nil)

    post :create, params: { signin: { email: user.email, password: '1234567890' } }

    assert user.reload.session_token.present?
    assert_equal user.session_token, @controller.session['user']['session_token']
  end

  test 'remember me signs the user back in and stores the current session token' do
    user = users(:founder)
    user.update_columns(session_token: 'existing-token')
    user.remember_me!
    @request.cookies[:remember_token] = user.remember_token

    get :show

    assert_redirected_to root_url
    assert_equal({ 'id' => user.id, 'session_token' => 'existing-token' }, @controller.session['user'])
  end

  test 'a session with an outdated token is treated as signed out' do
    user = users(:founder)
    user.update_columns(session_token: 'new-token')
    @request.session[:user] = { 'id' => user.id, 'session_token' => 'old-token' }

    get :show

    assert_redirected_to signin_path
    assert_nil @controller.session['user']
  end

  test 'a session for a user that no longer exists is treated as signed out' do
    @request.session[:user] = { 'id' => 0, 'session_token' => 'whatever' }

    get :show

    assert_redirected_to signin_path
  end

  test 'logout does not change the session token so other devices stay signed in' do
    user = users(:founder)
    user.update_columns(session_token: 'existing-token')
    @request.session[:user] = { 'id' => user.id, 'session_token' => 'existing-token' }

    delete :destroy

    assert_equal 'existing-token', user.reload.session_token
  end

  test 'the remember cookie holds the raw token, never the stored digest' do
    post :create, params: { signin: { email: users(:founder).email, password: '1234567890', remember_me: '1' } }

    user = users(:founder).reload
    assert_equal User.digest_remember_token(@response.cookies['remember_token']), user.remember_token_digest
  end

  test 'a remember token copied from the database does not sign anyone in' do
    user = users(:founder)
    user.remember_me!
    @request.cookies[:remember_token] = user.reload.remember_token_digest

    get :show

    assert_redirected_to signin_path
    assert_nil @controller.session['user']
  end
end
