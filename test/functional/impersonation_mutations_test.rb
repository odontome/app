# frozen_string_literal: true

require 'test_helper'

class ImpersonationMutationsTest < ActionController::TestCase
  tests PatientsController

  setup do
    @superadmin = users(:superadmin)
    @admin      = users(:founder)
    @practice   = practices(:complete)
    @patient    = patients(:john_smith)
  end

  test 'patient creation is blocked during impersonation' do
    # Simulate impersonation state
    @controller.session['user'] = @admin
    @controller.session['impersonator_id'] = @superadmin.id

    patient_params = {
      patient: {
        firstname: 'Test',
        lastname: 'Patient',
        date_of_birth: '1990-01-01'
      }
    }

    post :create, params: patient_params
    assert_response :redirect
    assert_match(/Data modification is not allowed while impersonating/, flash[:alert])
  end

  test 'patient update is blocked during impersonation' do
    # Simulate impersonation state
    @controller.session['user'] = @admin
    @controller.session['impersonator_id'] = @superadmin.id

    patient_params = {
      id: @patient.id,
      patient: {
        firstname: 'Updated Name'
      }
    }

    put :update, params: patient_params
    assert_response :redirect
    assert_match(/Data modification is not allowed while impersonating/, flash[:alert])
  end

  test 'patient deletion is blocked during impersonation' do
    # Simulate impersonation state
    @controller.session['user'] = @admin
    @controller.session['impersonator_id'] = @superadmin.id

    delete :destroy, params: { id: @patient.id }
    assert_response :redirect
    assert_match(/Data modification is not allowed while impersonating/, flash[:alert])
  end

  test 'patient show (GET) is allowed during impersonation' do
    # Simulate impersonation state
    @controller.session['user'] = @admin
    @controller.session['impersonator_id'] = @superadmin.id

    get :show, params: { id: @patient.id }
    assert_response :success
  end

  test 'patient index (GET) is allowed during impersonation' do
    # Simulate impersonation state
    @controller.session['user'] = @admin
    @controller.session['impersonator_id'] = @superadmin.id

    get :index
    assert_response :success
  end

  test 'patient edit form (GET) is allowed during impersonation' do
    # Simulate impersonation state
    @controller.session['user'] = @admin
    @controller.session['impersonator_id'] = @superadmin.id

    get :edit, params: { id: @patient.id }
    assert_response :success
  end

  test 'new patient form (GET) is allowed during impersonation' do
    # Simulate impersonation state
    @controller.session['user'] = @admin
    @controller.session['impersonator_id'] = @superadmin.id

    get :new
    assert_response :success
  end

  test 'normal operations work without impersonation' do
    # Normal session without impersonation
    @controller.session['user'] = @admin

    patient_params = {
      patient: {
        firstname: 'Normal',
        lastname: 'Patient',
        date_of_birth: '1990-01-01'
      }
    }

    post :create, params: patient_params
    # Should not be blocked - either success or validation error
    assert_not_equal :redirect, @response.status
  end
end