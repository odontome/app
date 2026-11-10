# frozen_string_literal: true

require 'test_helper'

class Api::Webhooks::StripeControllerTest < ActionController::TestCase
  setup do
    @practice = practices(:complete_another_language)
    @practice.update!(stripe_customer_id: 'cus_odontome_2')
  end

  test 'updates the subscription from a subscription event' do
    %w[past_due unpaid paused].each do |status|
      post_signed_event subscription_event(customer: 'cus_odontome_2', status: status)

      assert_response :ok
      assert_equal status, @practice.subscription.reload.status
    end
  end

  test 'responds with not found when no practice matches the stripe customer' do
    post_signed_event subscription_event(customer: 'cus_gone_123', status: 'active')

    assert_response :not_found
  end

  test 'rejects an invalid signature' do
    @request.headers['Stripe-Signature'] = 't=1,v1=invalid'
    post :event, body: subscription_event(customer: 'cus_odontome_2', status: 'active')

    assert_response :bad_request
  end

  test 'records a balance when the paid patient belongs to the practice' do
    patient = patients(:one)

    assert_difference -> { Balance.where(patient: patient).count }, 1 do
      post_signed_event payment_succeeded_event(practice_id: patient.practice_id, patient_id: patient.id)
    end

    assert_response :ok
  end

  test 'records one balance when the same payment event arrives twice' do
    patient = patients(:one)
    event = payment_succeeded_event(practice_id: patient.practice_id, patient_id: patient.id)

    assert_difference -> { Balance.where(patient: patient).count }, 1 do
      2.times { post_signed_event event }
    end

    assert_response :ok
  end

  test 'records the balance when the patient name is longer than a note allows' do
    patient = patients(:one)

    assert_difference -> { Balance.where(patient: patient).count }, 1 do
      post_signed_event payment_succeeded_event(practice_id: patient.practice_id, patient_id: patient.id,
                                                patient_name: 'x' * 200)
    end

    assert_response :ok
  end

  test 'a subscription whose first payment never went through leaves the practice as it was' do
    %w[incomplete incomplete_expired].each do |status|
      assert_no_changes -> { @practice.subscription.reload.attributes } do
        post_signed_event subscription_event(customer: 'cus_odontome_2', status: status)
      end

      assert_response :ok
    end
  end

  test 'skips the balance when the paid patient belongs to another practice' do
    other_patient = patients(:three)

    assert_no_difference -> { Balance.count } do
      post_signed_event payment_succeeded_event(practice_id: practices(:complete).id, patient_id: other_patient.id)
    end

    # 200 so Stripe doesn't keep retrying an event we will never accept
    assert_response :ok
  end

  private

  def payment_succeeded_event(practice_id:, patient_id:, patient_name: 'Someone')
    {
      id: 'evt_test_2',
      object: 'event',
      type: 'payment_intent.succeeded',
      data: {
        object: {
          id: 'pi_test_1',
          object: 'payment_intent',
          amount_received: 1000,
          currency: 'usd',
          metadata: { practice_id: practice_id.to_s, patient_id: patient_id.to_s, patient_name: patient_name }
        }
      }
    }.to_json
  end


  # customer.subscription.updated exercises update_database_subscription — the
  # same method the invoice.* events reach — without needing to stub the
  # Stripe::Subscription.retrieve network call those events make first.
  def subscription_event(customer:, status:)
    {
      id: 'evt_test_1',
      object: 'event',
      type: 'customer.subscription.updated',
      data: {
        object: {
          id: 'sub_test_1',
          object: 'subscription',
          customer: customer,
          status: status,
          cancel_at_period_end: false,
          current_period_start: 2.days.ago.to_i,
          current_period_end: 28.days.from_now.to_i
        }
      }
    }.to_json
  end

  def post_signed_event(payload)
    timestamp = Time.now.to_i
    secret = Rails.configuration.stripe[:webhook_secret]
    signature = OpenSSL::HMAC.hexdigest('SHA256', secret, "#{timestamp}.#{payload}")
    @request.headers['Stripe-Signature'] = "t=#{timestamp},v1=#{signature}"

    post :event, body: payload
  end
end
