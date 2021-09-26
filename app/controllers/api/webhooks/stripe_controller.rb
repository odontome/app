module Api::Webhooks
  class StripeController < ApplicationController
    skip_forgery_protection
    skip_before_action :check_subscription_status

    def event
      event = nil

      # You can find your endpoint's secret in the output of the `stripe listen`
      endpoint_secret = Rails.configuration.stripe[:webhook_secret]

      # Verify webhook signature and extract the event
      # See https://stripe.com/docs/webhooks/signatures for more information.
      begin
        sig_header = request.env['HTTP_STRIPE_SIGNATURE']
        payload = request.body.read
        event = Stripe::Webhook.construct_event(payload, sig_header, endpoint_secret)
      rescue JSON::ParserError => e
        return head :bad_request
      rescue Stripe::SignatureVerificationError => e
        return head :bad_request
      end

      #
      # Handle various events.  There are many more, but these are the essential ones.
      #
      case event.type
      when 'invoice.payment_succeeded'
        invoice = event.data.object
        subscription = Stripe::Subscription.retrieve(invoice.subscription)
        update_database_subscription(subscription)
      when 'invoice.payment_failed'
        invoice = event.data.object
        subscription = Stripe::Subscription.retrieve(invoice.subscription)
        update_database_subscription(subscription)
      when 'invoice.created', 'customer.subscription.deleted', 'customer.subscription.updated'
        subscription = event.data.object
        update_database_subscription(subscription)
      when 'checkout.session.completed'
        subscription = event.data.object
        update_customer_reference(subscription)
      else
        puts "Stripe webhooks - unhandled event: #{event.type}"
      end

      head 200
    end

    private

    #
    # Use the same method that we wrote for create new subscriptions to update the
    # subscription data, so that it's always formatted consistently.
    #
    def update_database_subscription(stripe_sub)
      practice = Practice.find_by!(stripe_customer_id: stripe_sub.customer)
      subscription = practice.subscription
      subscription.assign_stripe_attrs(stripe_sub)
      subscription.save!
    end

    def update_customer_reference(stripe_sub)
      practice = Practice.find_by!(id: stripe_sub.client_reference_id)
      practice.stripe_customer_id = stripe_sub.customer
      practice.save!
    end
  end
end
