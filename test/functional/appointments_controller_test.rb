require 'test_helper'

class AppointmentsControllerTest < ActionController::TestCase
  
  setup do
  	current_user = users(:founder)
  	controller.session["user_credentials"] = users(:founder).persistence_token
  end
  
  test "should get index" do
    get :index, :datebook_id => 1, :format => "json"
    assert_response :success
    assert_not_nil assigns(:appointments)
  end
  
	test "should get new" do
	  get :new, :datebook_id => 1
	  assert_response :success
	end

  test "should create an appointment with an existing patient" do
    existing_patient = {
      :doctor_id => 1,
      :starts_at => '2014-01-04 14:00:00 +0000',
      :ends_at => '2014-01-04 15:00:00 +0000'
    }

    assert_difference 'Appointment.count' do
      post :create, { appointment: existing_patient, datebook_id: 1, as_values_patient_id: "4," } 
      # see Patient.find_or_create_from to understand the 'as_values_patient_id' property
    end
  end

  test "should create an appointment with a new patient" do
    new_patient = {
      :doctor_id => 2,
      :starts_at => '2014-01-04 14:00:00 +0000',
      :ends_at => '2014-01-04 15:00:00 +0000'
    }

    assert_difference ['Patient.count', 'Appointment.count'] do
      post :create, { appointment: new_patient, datebook_id: 1, as_values_patient_id: "New patient" }
      # see Patient.find_or_create_from to understand the 'as_values_patient_id' property
    end
  end

  test "should not create an appointment with in a foreign practice" do
    new_patient = {
      :doctor_id => 2,
      :starts_at => '2014-01-04 14:00:00 +0000',
      :ends_at => '2014-01-04 15:00:00 +0000'
    }

    assert_no_difference ['Appointment.count'] do
      post :create, { appointment: new_patient, datebook_id: 9, as_values_patient_id: "New patient" }
      # see Patient.find_or_create_from to understand the 'as_values_patient_id' property
    end
  end

end