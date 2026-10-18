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

  test 'new ignores a practice_id that belongs to another practice' do
    get :new, params: { practice_id: practices(:trialing_practice).id }
    assert_response :success
    assert_equal @practice, assigns(:practice)
  end

  test 'create sends the money to the current practice even when another practice_id is passed' do
    practices(:trialing_practice).update!(stripe_account_id: 'acct_other_practice',
                                          connect_charges_enabled: true, connect_payouts_enabled: true)

    intent_params = create_payment(practice_id: practices(:trialing_practice).id)

    assert_equal 'acct_test_123456789', intent_params[:transfer_data][:destination]
    assert_equal @practice.id.to_s, intent_params[:metadata][:practice_id]
  end

  test 'create keeps the patient when they belong to the current practice' do
    intent_params = create_payment(patient_id: patients(:one).id)

    assert_equal patients(:one).id.to_s, intent_params[:metadata][:patient_id]
  end

  test 'create drops a patient that belongs to another practice' do
    intent_params = create_payment(patient_id: patients(:three).id)

    assert_nil intent_params[:metadata][:patient_id]
  end

  private

  # Stubs the Stripe call and returns the params the controller sent to it
  def create_payment(extra_params)
    captured = nil
    fake_intent = Struct.new(:client_secret).new('pi_test_secret_abc')

    Stripe::PaymentIntent.stub(:create, lambda { |intent_params|
      captured = intent_params
      fake_intent
    }) do
      post :create, params: { amount: '10', patient_name: 'Someone' }.merge(extra_params)
    end

    assert_response :success
    captured
  end
end
