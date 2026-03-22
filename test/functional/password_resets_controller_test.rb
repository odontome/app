# frozen_string_literal: true

require 'test_helper'

class PasswordResetsControllerTest < ActionController::TestCase
  test 'new renders the password reset form' do
    get :new
    assert_response :success
  end

  test 'create sends reset instructions for a valid email' do
    user = users(:founder)
    emails_before = ActionMailer::Base.deliveries.size

    post :create, params: { email: user.email }

    assert_equal emails_before + 1, ActionMailer::Base.deliveries.size
    assert_equal I18n.t(:password_reset_instructions_sent_to_email), flash[:notice]
    assert_redirected_to root_path
  end

  test 'create shows error for an unknown email' do
    emails_before = ActionMailer::Base.deliveries.size

    post :create, params: { email: 'unknown@example.com' }

    assert_equal emails_before, ActionMailer::Base.deliveries.size
    assert_equal I18n.t(:no_user_with_that_email, email: 'unknown@example.com'), flash[:error]
    assert_template :new
  end

  test 'edit renders the password form with a valid token' do
    user = users(:founder)
    user.update_columns(perishable_token: 'valid_token_123', updated_at: 1.minute.ago)

    get :edit, params: { id: 'valid_token_123' }

    assert_response :success
  end

  test 'edit redirects when the token is expired' do
    user = users(:founder)
    user.update_columns(perishable_token: 'expired_token_123', updated_at: 20.minutes.ago)

    get :edit, params: { id: 'expired_token_123' }

    assert_equal I18n.t('errors.messages.reset_your_password_token_expired'), flash[:error]
    assert_redirected_to root_url
  end

  test 'edit redirects when the token does not exist' do
    get :edit, params: { id: 'nonexistent_token' }

    assert_equal I18n.t('errors.messages.reset_your_password_token_expired'), flash[:error]
    assert_redirected_to root_url
  end

  test 'update changes the password with valid input' do
    user = users(:founder)
    user.update_columns(perishable_token: 'reset_token_456', updated_at: 1.minute.ago)

    patch :update, params: { id: 'reset_token_456', password: 'newpassword123', password_confirmation: 'newpassword123' }

    assert_equal I18n.t(:password_reset_success_message), flash[:notice]
    assert_redirected_to root_path

    user.reload
    assert user.authenticate('newpassword123')
  end

  test 'update re-renders edit when password is too short' do
    user = users(:founder)
    user.update_columns(perishable_token: 'reset_token_789', updated_at: 1.minute.ago)

    patch :update, params: { id: 'reset_token_789', password: 'short' }

    assert_template :edit
  end

  test 'logged in users cannot access password reset' do
    @controller.session[:user] = users(:founder)

    get :new

    assert_redirected_to root_path
  end
end
