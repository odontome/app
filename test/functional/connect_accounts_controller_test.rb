# frozen_string_literal: true

require 'test_helper'

class ConnectAccountsControllerTest < ActionController::TestCase
  
  def setup
    @practice = practices(:practice_one)
    @user = users(:user_one)
    @user.practice = @practice
    @user.save!
    
    session[:user_id] = @user.id
  end

  test "should get show" do
    get :show
    assert_response :success
    assert_not_nil assigns(:practice)
  end

  test "should redirect to settings when practice not found" do
    session[:user_id] = nil
    get :show
    assert_redirected_to signin_path
  end

  test "show refreshes connect account status when account exists" do
    @practice.update!(stripe_account_id: 'acct_test123')
    
    # Mock the Stripe call to avoid actual API calls in tests
    @practice.expects(:refresh_connect_account_status!).once
    
    get :show
    assert_response :success
  end

  test "create redirects to onboarding after creating account" do
    # Mock Stripe account creation
    @practice.expects(:create_connect_account!).once
    
    post :create
    assert_redirected_to connect_onboarding_path
  end

  test "create handles stripe errors gracefully" do
    # Mock Stripe error
    @practice.expects(:create_connect_account!).raises(Stripe::StripeError.new("Test error"))
    
    post :create
    assert_redirected_to practice_settings_path
    assert_not_nil flash[:error]
  end
end