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

  test 'letter listing uses cursor pagination' do
    practice = practices(:complete)
    total_records = PatientsController::LETTER_PAGE_SIZE + 1

    total_records.times do |index|
      Patient.create!(
        practice: practice,
        firstname: "Alice#{index}",
        lastname: 'Cursor',
        uid: "CUR#{index}",
        date_of_birth: Date.new(1990, 1, 1)
      )
    end

    get :index, params: { letter: 'A' }

    assert_response :success
    assert_equal PatientsController::LETTER_PAGE_SIZE, assigns(:patients).size
    assert assigns(:next_cursor).present?
    assert_equal 'A', assigns(:current_letter)
  end

  test 'cursor parameter returns subsequent patients' do
    practice = practices(:complete)
    total_records = PatientsController::LETTER_PAGE_SIZE + 2

    total_records.times do |index|
      Patient.create!(
        practice: practice,
        firstname: format('Aaron%03d', index),
        lastname: 'FollowUp',
        uid: "CURA#{index}",
        date_of_birth: Date.new(1990, 2, 2)
      )
    end

    get :index, params: { letter: 'A' }
    cursor = assigns(:next_cursor)

    assert cursor.present?

    get :index, params: { letter: 'A', cursor: cursor }

    assert_response :success
    assert assigns(:patients).size.positive?
    assert_nil assigns(:next_cursor)
  end
end
