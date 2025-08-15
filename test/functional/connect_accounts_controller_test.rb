# frozen_string_literal: true

require 'test_helper'

class ConnectAccountsControllerTest < ActionController::TestCase
  def setup
    @user = users(:founder)
    @controller.session['user'] = @user
  end

  test 'create requires authenticated user' do
    session.clear
    post :create
    assert_redirected_to signin_path
  end

  test 'onboarding requires authenticated user' do
    session.clear
    get :onboarding
    assert_redirected_to signin_path
  end

  test 'refresh_status requires authenticated user' do
    session.clear
    post :refresh_status
    assert_redirected_to signin_path
  end
end
