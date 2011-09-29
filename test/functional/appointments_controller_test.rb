require 'test_helper'

class AppointmentsControllerTest < ActionController::TestCase
  
  setup do
  	current_user = users(:founder)
  	controller.session["user_credentials"] = users(:founder).persistence_token
  	
  	@new_appointment = { :doctor_id => 1,
			  								 :patient_id => 1
			  							 }
  end
  
  test "should get index" do
    get :index, :format => "json"
    assert_response :success
    assert_not_nil assigns(:appointments)
  end
  
	test "should get new" do
	  get :new
	  assert_response :success
	end

end