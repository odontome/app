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
    get :index, params: { q: patients(:four).firstname }
    assert_not_nil assigns(:patients)
  end

  test 'should not get search results' do
    get :index, params: { q: patients(:four).email }
    assert assigns(:patients).empty?
  end

  test 'should update patient' do
    put :update, params: { id: patients(:one).to_param, practice: @new_patient }
    assert_redirected_to patient_path(assigns(:patient))
  end

  test 'should destroy patient' do
    assert_difference('Patient.count', -1) do
      delete :destroy, params: { id: patients(:one).to_param }
    end

    assert_redirected_to patients_path
  end
end
