# frozen_string_literal: true

require 'test_helper'

class BalancesControllerTest < ActionController::TestCase
  setup do
    @controller.session['user'] = users(:founder)
  end

  test 'should get index' do
    get :index, params: { patient_id: 1 }
    assert_response :success
    assert_not_nil assigns(:treatments)
  end

  test 'should create an income entry' do
    entry = {
      amount: 9.99,
      currency: 'usd',
      notes: 'Can of soda'
    }

    assert_difference 'Balance.count' do
      post :create, params: { balance: entry, patient_id: 1, format: :js }
    end
  end

  test 'should create an expense entry' do
    entry = {
      amount: -9.99,
      currency: 'usd',
      notes: 'Returned the can of soda'
    }

    assert_difference 'Balance.count' do
      post :create, params: { balance: entry, patient_id: 1, format: :js }
    end
  end
end
