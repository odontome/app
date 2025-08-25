# frozen_string_literal: true

require 'test_helper'

class PaymentsControllerTest < ActionController::TestCase
  setup do
    @practice = practices(:complete)
    @user = users(:founder)
    @controller.session['user'] = @user
  end

  test 'should get index and handle empty payments gracefully' do
    # The test will handle the Stripe error gracefully due to our error handling
    get :index
    assert_response :success
    assert_not_nil assigns(:payments_with_transfers)
  end

  test 'should get new with practice_id' do
    get :new, params: { practice_id: @practice.id }
    assert_response :success
    assert_not_nil assigns(:practice)
  end

  test 'should redirect when practice not found' do
    get :new, params: { practice_id: 999_999 }
    assert_redirected_to root_path
    assert_equal 'Practice not found', flash[:error]
  end
end
