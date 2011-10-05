require 'test_helper'

class PatientsControllerTest < ActionController::TestCase
  
  setup do
  	controller.session["user_credentials"] = users(:founder).persistence_token
  	
  	@new_patient = {:practice_id => 1,
  									:firstname => "Daniella",
										:lastname => "Sanguino",
										:date_of_birth => "1988-11-16",
										:past_illnesses => "none",
										:surgeries => "none",
										:medications => "none",
										:drugs_use => "none",
										:cigarettes_per_day => 0,
										:drinks_per_day => 0,
										:family_diseases => "none",
										:emergency_telephone => "call my mom"
									}  	
  end
  
  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:patients)
  end
  
	test "should get new" do
	  get :new
	  assert_response :success
	end
  
  test "should create patient" do
    assert_difference('Patient.count') do
      post :create, patient: @new_patient
    end
    assert_redirected_to patient_path(assigns(:patient))
  end
  
  test "should show patient" do
    get :show, id: patients(:one).to_param
    assert_response :success
  end
  
  test "should get edit" do
    get :edit, id: patients(:one).to_param
    assert_response :success
  end
  
  test "should update patient" do
    put :update, id: patients(:one).to_param, practice: @new_patient
    assert_redirected_to patient_path(assigns(:patient))
  end

  test "should destroy patient" do
    assert_difference('Patient.count', -1) do
      delete :destroy, id: patients(:one).to_param
    end
				
    assert_redirected_to patients_path
  end
  
end