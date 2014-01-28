require 'test_helper'

class TreatmentsControllerTest < ActionController::TestCase
  
  setup do
  	UserSession.create users(:founder)
  	
  	@treatment = { :name => "Cleaning", :price => 19.99 }
  end
  
  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:treatments)
  end
  
	test "should get new" do
	  get :new
	  assert_response :success
	end
  
  test "should create treatment" do
    assert_difference('Treatment.count') do
      post :create, treatment: @treatment
    end
    assert_redirected_to treatments_url
  end
    
  test "should get edit" do
    get :edit, id: treatments(:incomplete).to_param
    assert_response :success
  end

  test "should update treatment" do
    put :update, id: treatments(:complete).to_param, treatment: @treatment
    assert_redirected_to treatments_url
  end

  test "should destroy treatment" do
    assert_difference('Treatment.count', -1) do
      delete :destroy, id: treatments(:complete).to_param
    end
				
    assert_redirected_to treatments_url
  end

end