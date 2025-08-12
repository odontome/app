# frozen_string_literal: true

require 'test_helper'

class AdminControllerTest < ActionController::TestCase
  setup do
    @controller.session['user'] = users(:superadmin)
  end

  test 'should get practices with all filter' do
    get :practices
    assert_response :success
    assert_equal 5, assigns(:practices).count
    assert_equal 'all', assigns(:filter)
  end

  test 'should get practices with active filter' do
    get :practices, params: { filter: 'active' }
    assert_response :success
    # Should include practices with active subscription status
    active_practices = assigns(:practices)
    assert active_practices.any? { |p| p.subscription.status == 'active' }
    assert_equal 'active', assigns(:filter)
  end

  test 'should get practices with trialing filter' do
    get :practices, params: { filter: 'trialing' }
    assert_response :success
    # Should include practices with trialing subscription status
    trialing_practices = assigns(:practices)
    assert trialing_practices.any? { |p| p.subscription.status == 'trialing' }
    assert_equal 'trialing', assigns(:filter)
  end

  test 'should get practices with past_due filter' do
    get :practices, params: { filter: 'past_due' }
    assert_response :success
    # Should include practices with past_due subscription status
    past_due_practices = assigns(:practices)
    assert past_due_practices.any? { |p| p.subscription.status == 'past_due' }
    assert_equal 'past_due', assigns(:filter)
  end

  test 'should get practices with canceled filter' do
    get :practices, params: { filter: 'canceled' }
    assert_response :success
    # Should include practices with canceled subscription status
    canceled_practices = assigns(:practices)
    assert canceled_practices.any? { |p| p.subscription.status == 'canceled' }
    assert_equal 'canceled', assigns(:filter)
  end


  test 'should require superadmin access' do
    @controller.session['user'] = users(:founder) # Regular admin, not superadmin
    get :practices
    assert_redirected_to '/401'
  end

  test 'should require authentication' do
    @controller.session['user'] = nil
    get :practices
    assert_redirected_to '/401'
  end
end