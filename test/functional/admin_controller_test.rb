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

  test 'shows signup funnel stats for the last 30 days' do
    fresh = practices(:trialing_practice)
    fresh.update_columns(created_at: 3.days.ago, doctors_count: 1, patients_count: 2)
    activated_and_paying = practices(:complete)
    activated_and_paying.update_columns(created_at: 10.days.ago, doctors_count: 3, patients_count: 3)
    activated_and_paying.subscription.update_columns(status: 'active')
    Practice.where.not(id: [fresh.id, activated_and_paying.id]).update_all(created_at: 60.days.ago)

    get :practices

    assert_response :success
    assert_equal 2, assigns(:funnel)[:signups]
    assert_equal 2, assigns(:funnel)[:activated]
    assert_equal 1, assigns(:funnel)[:subscribed]
    assert_match(/Last 30 days: 2 signups\s+· 2 activated \(100%\)\s+· 1 subscribed/, response.body)
  end

  test 'funnel handles zero signups without division errors' do
    Practice.update_all(created_at: 60.days.ago)

    get :practices

    assert_response :success
    assert_equal 0, assigns(:funnel)[:signups]
    assert_match(/Last 30 days: 0 signups/, response.body)
  end

  test 'should get practices with active filter' do
    get :practices, params: { filter: 'active' }
    assert_response :success
    # Should include practices with active subscription status
    active_practices = assigns(:practices)
    assert(active_practices.any? { |p| p.subscription.status == 'active' })
    assert_equal 'active', assigns(:filter)
  end

  test 'should get practices with trialing filter' do
    get :practices, params: { filter: 'trialing' }
    assert_response :success
    # Should include practices with trialing subscription status
    trialing_practices = assigns(:practices)
    assert(trialing_practices.any? { |p| p.subscription.status == 'trialing' })
    assert_equal 'trialing', assigns(:filter)
  end

  test 'should get practices with past_due filter' do
    get :practices, params: { filter: 'past_due' }
    assert_response :success
    # Should include practices with past_due subscription status
    past_due_practices = assigns(:practices)
    assert(past_due_practices.any? { |p| p.subscription.status == 'past_due' })
    assert_equal 'past_due', assigns(:filter)
  end

  test 'should get practices with canceled filter' do
    get :practices, params: { filter: 'canceled' }
    assert_response :success
    # Should include practices with canceled subscription status
    canceled_practices = assigns(:practices)
    assert(canceled_practices.any? { |p| p.subscription.status == 'canceled' })
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

  test 'should reject stop impersonating for invalid impersonation session' do
    @controller.session['user'] = users(:founder)
    @controller.session['impersonator_id'] = users(:founder).id

    delete :stop_impersonating

    assert_redirected_to root_path
    assert_nil @controller.session['impersonator_id']
  end
end
