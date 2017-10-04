require 'test_helper'

class UserSessionsControllerTest < ActionController::TestCase

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create user session if valid params are given" do
    post :create, params: { user_session: { :email => 'raulriera@hotmail.com', :password => '1234567890' } }

    assert_equal controller.session["user_credentials"], users(:founder).persistence_token
    assert_redirected_to root_url
  end

  test "should see login form if no valid params are given" do
    post :create, params: {user_session: {}}

    assert_nil controller.session["user_credentials"]
    assert_template 'new'
  end

  test "should block user session if force entering" do
    # spam the login form
    15.times do
      post :create, params: {:user_session => { :email => 'raulriera@hotmail.com', :password => '12345' }}
    end
    # try to enter valid credentials
    post :create, params: {:user_session => { :email => 'raulriera@hotmail.com', :password => '1234567890' }}

    assert_template 'new'
  end

end
