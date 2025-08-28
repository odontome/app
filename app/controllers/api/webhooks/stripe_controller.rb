module Api::Webhooks
  class StripeController < ApplicationController
    skip_forgery_protection
    skip_before_action :check_subscription_status
    skip_before_action :prevent_impersonation_mutations

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
      rescue JSON::ParserError
        return head :bad_request
      rescue Stripe::SignatureVerificationError
        return head :bad_request
      end

      #
      # Handle various events.  There are many more, but these are the essential ones.
      #
      case event.type

      # Subscription events
      when 'invoice.payment_succeeded'
        invoice = event.data.object
        subscription = Stripe::Subscription.retrieve(invoice.subscription)
        update_database_subscription(subscription)
      when 'invoice.payment_failed'
        invoice = event.data.object
        subscription = Stripe::Subscription.retrieve(invoice.subscription)
        update_database_subscription(subscription)
      when 'customer.subscription.deleted', 'customer.subscription.updated'
        subscription = event.data.object
        update_database_subscription(subscription)
      when 'checkout.session.completed'
        subscription = event.data.object
        update_customer_reference(subscription)

      # Connect events
      when 'account.updated'
        handle_account_updated(event)
      when 'payment_intent.succeeded'
        handle_payment_succeeded(event)

      # Everything else
      else
        puts "Stripe webhooks - unhandled event: #{event.type}"
      end

      head 200
    end

    private

    # Stripe Subscription

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

    # Stripe Connect

    def handle_account_updated(event)
      account = event.data.object
      practice = Practice.find_by!(stripe_account_id: account.id)
      practice.update!(
        connect_charges_enabled: account.charges_enabled,
        connect_payouts_enabled: account.payouts_enabled,
        connect_details_submitted: account.details_submitted,
        connect_onboarding_status: practice.determine_onboarding_status_from_stripe_account(account)
      )
    end

    def handle_payment_succeeded(event)
      payment_intent = event.data.object
      notes = payment_intent.metadata&.patient_name
      # practice_id = payment_intent.metadata&.practice_id
      patient_id = payment_intent.metadata&.patient_id

      return unless patient_id

      Balance.create!(
        amount: payment_intent.amount_received / 100.0,
        currency: payment_intent.currency,
        notes: notes,
        patient_id: patient_id
      )
    end
  end
end
