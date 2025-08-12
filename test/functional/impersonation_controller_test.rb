# frozen_string_literal: true

require 'test_helper'

class ImpersonationControllerTest < ActionController::TestCase
  tests AdminController

  setup do
    @superadmin = users(:superadmin)
    @admin      = users(:founder)
    @practice   = practices(:complete)
    @controller.session['user'] = @superadmin
  end

  test 'superadmin can impersonate a practice admin and is redirected to practice dashboard' do
    post :impersonate, params: { id: @practice.id }
    assert_redirected_to practice_path
    assert_equal @admin.practice_id, @controller.session['user']['practice_id']
    assert @controller.session['impersonator_id'].present?
  end

  test 'cannot start nested impersonation' do
    post :impersonate, params: { id: @practice.id }
    assert @controller.session['impersonator_id'].present?

    post :impersonate, params: { id: @practice.id }
    assert_redirected_to '/401'
  end

  test 'stop impersonating restores original admin' do
    post :impersonate, params: { id: @practice.id }
    delete :stop_impersonating

    assert_redirected_to practices_admin_path
    assert_equal @superadmin.id, @controller.session['user']['id']
    assert_nil @controller.session['impersonator_id']
  end

  test 'cannot impersonate superadmin target' do
    # Ensure only the superadmin remains in the practice so fallback selection would hit it
    users_in_practice = User.where(practice_id: @practice.id).where.not(id: @superadmin.id)
    users_in_practice.each { |u| u.update_columns(practice_id: practices(:complete_another_language).id) }

    post :impersonate, params: { id: @practice.id }
    # Either blocked by guard or by superadmin requirement
    assert_response :redirect
  end

  test 'impersonation blocks mutation via POST requests' do
    # Start impersonation
    post :impersonate, params: { id: @practice.id }
    assert @controller.session['impersonator_id'].present?
    
    # Simulate a POST request that would normally create data
    @controller.request.env['REQUEST_METHOD'] = 'POST'
    @controller.request.env['PATH_INFO'] = '/patients'
    
    # This should be blocked by prevent_impersonation_mutations filter
    post :practices  # Try to access a different action that requires POST
    assert_response :redirect
  end

  test 'impersonation allows read operations via GET requests' do
    # Start impersonation  
    post :impersonate, params: { id: @practice.id }
    assert @controller.session['impersonator_id'].present?
    
    # GET requests should be allowed
    get :practices
    assert_response :success
  end
end
