# frozen_string_literal: true

require 'test_helper'

class Api::Webhooks::StripeControllerTest < ActionController::TestCase
  setup do
    @practice = practices(:complete_another_language)
    @practice.update!(stripe_customer_id: 'cus_odontome_2')
  end

  test 'updates the subscription from a subscription event' do
    post_signed_event subscription_event(customer: 'cus_odontome_2', status: 'past_due')

    assert_response :ok
    assert_equal 'past_due', @practice.subscription.reload.status
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

  private

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
