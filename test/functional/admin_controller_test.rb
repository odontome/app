# frozen_string_literal: true

require 'test_helper'

class AdminControllerTest < ActionController::TestCase
  setup do
    @controller.session['user'] = users(:superadmin)
  end

  test 'should get practices with all filter' do
    get :practices
    assert_response :success
    expected = practices(:complete, :complete_another_language, :trialing_practice, :past_due_practice, :canceled_practice)
    assert_equal expected.map(&:id).sort, assigns(:practices).map(&:id).sort
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

  {
    'active' => [:complete_another_language],
    'trialing' => [:complete, :trialing_practice],
    'past_due' => [:past_due_practice],
    'canceled' => [:canceled_practice]
  }.each do |filter, fixture_names|
    test "should get practices with #{filter} filter" do
      get :practices, params: { filter: filter }

      assert_response :success
      expected_ids = fixture_names.map { |name| practices(name).id }
      assert_equal expected_ids.sort, assigns(:practices).map(&:id).sort
      assert_equal filter, assigns(:filter)
    end
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
