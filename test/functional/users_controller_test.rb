require 'test_helper'

class UsersControllerTest < ActionController::TestCase
  setup do
  	@controller.session["user"] = users(:founder)
  	
  	@new_user = { :firstname => "Rebecca",
  								:lastname => "Riera",
  								:email => "rebeccariera@bokanova.mx",
  								:password => "12345678",
  								:password_confirmation => "12345678"
  							}
  end
  
  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:users)
  end
  
	test "should get new" do
	  get :new
	  assert_response :success
	end
  
  test "should create user" do
    assert_difference('User.count') do
      post :create, params: {user: @new_user}
    end
    assert_redirected_to users_url
  end
  
  test "should show user" do
    get :show, params: {id: users(:founder).to_param}
    assert_response :success
  end
  
  test "should get edit" do
    get :edit, params: {id: users(:founder).to_param}
    assert_response :success
  end
  
  test "should update user" do
    put :update, params: {id: users(:founder).to_param, user: @new_user}
    assert_redirected_to user_url
  end

  test "should destroy user" do
    assert_difference('User.count', -1) do
      delete :destroy, params: {id: users(:perishable).to_param}
    end
				
    assert_redirected_to users_path
  end
  
end
