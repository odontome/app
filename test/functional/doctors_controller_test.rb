require 'test_helper'

class DoctorsControllerTest < ActionController::TestCase

  setup do
  	current_user = users(:founder)
  	controller.session["user_credentials"] = users(:founder).persistence_token

  	@new_doctor = { :firstname => "Ruth",
  								:lastname => "Riera",
  								:email => "ruthriera@dentifels.com"
  							}
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:doctors)
  end

	test "should get new" do
	  get :new
	  assert_response :success
	end

  test "should create doctor" do
    assert_difference('Doctor.count') do
      post :create, params: {doctor: @new_doctor}
    end
    assert_redirected_to doctors_url
  end

  test "should show doctor" do
    get :show, params: {id: doctors(:rebecca).to_param}
    assert_response :success
  end

  test "should get edit" do
    get :edit, params: {id: doctors(:rebecca).to_param}
    assert_response :success
  end

  test "should get calendar subscription" do
    doctor = doctors(:rebecca)
    ciphered_url_encoded_id = Cipher.encode(doctor.id.to_s)

    get :appointments, params: {doctor_id: ciphered_url_encoded_id}, :format => :ics
    assert_response :success
  end

  test "should update doctor" do
    put :update, params: {id: doctors(:rebecca).to_param, doctor: @new_doctor}
    assert_redirected_to doctors_url
  end

  test "should destroy doctor" do
    assert_difference('Doctor.count', -1) do
      delete :destroy, params: {id: doctors(:perishable).to_param}
    end

    assert_redirected_to doctors_path
  end

end
