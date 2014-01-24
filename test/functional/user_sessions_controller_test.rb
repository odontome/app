require 'test_helper'

class UserSessionsControllerTest < ActionController::TestCase

  def valid_user_session_attributes
    @valid_user_session_attributes ||= { :email => 'raulriera@hotmail.com', :password => '1234567890' }
  end

  test "should get new" do
    get :new
    assert_response :success
  end
  
  test "should create user session if valid params are given" do
    post :create, :user_session => valid_user_session_attributes
    
    assert_equal controller.session["user_credentials"], users(:founder).persistence_token
    assert_redirected_to root_url
  end
  
  test "should render login form if no valid params are given" do
    post :create, :user_session => {}
    
    assert_nil controller.session["user_credentials"]    
    assert_template 'new'
  end

end