require 'test_helper'

class DatebooksControllerTest < ActionController::TestCase
  
  setup do
  	UserSession.create users(:founder)
  	
  	@datebook = { :name => "Bokanova Dental" }
  end
  
  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:datebooks)
  end
  
	test "should get new" do
	  get :new
	  assert_response :success
	end

  test "should not get new if not admin" do
    UserSession.create users(:perishable)

    get :new
    assert_response :redirect
  end
  
  test "should create datebook" do
    assert_difference('Datebook.count') do
      post :create, datebook: @datebook
    end
    assert_redirected_to datebooks_url
  end
  
  test "should show datebook" do
    get :show, id: datebooks(:playa_del_carmen).to_param
    assert_response :success
  end
  
  test "should get edit" do
    get :edit, id: datebooks(:playa_del_carmen).to_param
    assert_response :success
  end

  test "should not get edit if not admin" do
    UserSession.create users(:perishable)

    get :edit
    assert_response :redirect
  end
  
  test "should update datebook" do
    put :update, id: datebooks(:playa_del_carmen).to_param, datebook: @datebook
    assert_redirected_to datebooks_url
  end

  test "should destroy datebook without appointments" do
    assert_difference('Datebook.count', -1) do
      delete :destroy, id: datebooks(:without_appointments).to_param
    end
				
    assert_redirected_to datebooks_url
  end

  test "should not destroy datebook with appointments" do
    assert_no_difference('Datebook.count') do
      delete :destroy, id: datebooks(:playa_del_carmen).to_param
    end
        
    assert_redirected_to datebooks_url
  end

end