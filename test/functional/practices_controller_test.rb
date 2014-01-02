require 'test_helper'

class PracticesControllerTest < ActionController::TestCase
  
  setup do
  	current_user = users(:founder)
  	controller.session["user_credentials"] = users(:founder).persistence_token
  	
  	@new_practice = Practice.new(:name => "Demo practice")
  	@new_practice.users << users(:founder)
  end
  
	test "should get new" do
		controller.session["user_credentials"] = nil
	  get :new
	  assert_response :success
	end
    
  test "should show practice" do
    get :show, id: practices(:complete).to_param
    assert_response :success
  end
  
end