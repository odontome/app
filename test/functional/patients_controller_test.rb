# frozen_string_literal: true

require 'test_helper'

class PatientsControllerTest < ActionController::TestCase
  setup do
    @controller.session['user'] = users(:founder)

    @new_patient = {
      firstname: 'Daniella',
      lastname: 'Sanguino',
      date_of_birth: '1988-11-16',
      uid: 'RR0001'
    }
  end

  test 'should get index' do
    get :index
    assert_response :success
    assert_not_nil assigns(:patients)
  end

  test 'should get new' do
    get :new
    assert_response :success
  end

  test 'should create patient' do
    assert_difference('Patient.count') do
      post :create, params: { patient: @new_patient }
    end
    assert_redirected_to patient_path(assigns(:patient))
  end

  test 'should show patient' do
    get :show, params: { id: patients(:one).to_param }
    assert_response :success
  end

  test 'should get edit' do
    get :edit, params: { id: patients(:one).to_param }
    assert_response :success
  end

  test 'should get search results' do
    get :index, params: { term: patients(:four).firstname }
    assert_not_nil assigns(:patients)
  end

  test 'should not get search results' do
    get :index, params: { term: patients(:four).email }
    assert assigns(:patients).empty?
  end

  test 'should handle search with backslash character' do
    # This test ensures the SQL injection vulnerability is fixed
    # Previously, searching with a term ending in backslash would cause a PostgreSQL error
    get :index, params: { term: 'test\\' }
    assert_response :success
    assert_not_nil assigns(:patients)
    # Should return empty results but not cause an error
    assert assigns(:patients).empty?
  end

  test 'should handle search with other special characters' do
    # Test searching with other LIKE pattern special characters
    get :index, params: { term: 'test%_' }
    assert_response :success
    assert_not_nil assigns(:patients)
    # Should return empty results but not cause an error
    assert assigns(:patients).empty?
  end

  test 'should update patient' do
    put :update, params: { id: patients(:one).to_param, patient: @new_patient }
    assert_redirected_to patient_path(assigns(:patient))
  end

  test 'should destroy patient' do
    assert_difference('Patient.count', -1) do
      delete :destroy, params: { id: patients(:one).to_param }
    end

    assert_redirected_to patients_path
  end

  test 'should suspend patient when has appointments' do
    patient = patients(:two) # This patient should have appointments based on fixtures
    assert patient.is_active

    # Should not actually delete the patient, just set deleted_at
    assert_no_difference('Patient.count') do
      delete :destroy, params: { id: patient.to_param }
    end

    patient.reload
    assert patient.deleted?
    assert_redirected_to patients_path
  end

  test 'should activate suspended patient' do
    patient = patients(:two)
    patient.update(deleted_at: Time.current)

    # Should toggle back to active (clear deleted_at)
    assert_no_difference('Patient.count') do
      delete :destroy, params: { id: patient.to_param }
    end

    patient.reload
    assert patient.is_active
    assert_redirected_to patients_path
  end

  test 'should only show active patients in index' do
    patient = patients(:two)
    patient.update(deleted_at: Time.current)

    get :index

    assert_not assigns(:patients).include?(patient)
  end
end
