# frozen_string_literal: true

module Api::Webhooks
  class StripeConnectController < ApplicationController
    skip_forgery_protection
    skip_before_action :check_subscription_status
    skip_before_action :prevent_impersonation_mutations

    def event
      event = nil

      # Get the Connect webhook secret
      endpoint_secret = Rails.configuration.stripe[:connect_webhook_secret]

      return head :bad_request unless endpoint_secret

      # Verify webhook signature and extract the event
      begin
        sig_header = request.env['HTTP_STRIPE_SIGNATURE']
        payload = request.body.read
        event = Stripe::Webhook.construct_event(payload, sig_header, endpoint_secret)
      rescue JSON::ParserError => e
        Rails.logger.error "Stripe Connect webhook - JSON parse error: #{e.message}"
        return head :bad_request
      rescue Stripe::SignatureVerificationError => e
        Rails.logger.error "Stripe Connect webhook - signature verification failed: #{e.message}"
        return head :bad_request
      end

      # Handle Connect-specific events
      case event.type
      when 'account.updated'
        handle_account_updated(event)
      when 'account.application.deauthorized'
        handle_account_deauthorized(event)
      when 'payment_intent.succeeded'
        handle_payment_succeeded(event)
      when 'transfer.created'
        handle_transfer_created(event)
      else
        Rails.logger.info "Stripe Connect webhook - unhandled event: #{event.type}"
      end

      head 200
    end

    private

    def handle_account_updated(event)
      account = event.data.object
      practice = find_practice_by_account_id(account.id)

      if practice
        practice.update!(
          connect_charges_enabled: account.charges_enabled,
          connect_payouts_enabled: account.payouts_enabled,
          connect_details_submitted: account.details_submitted,
          connect_onboarding_status: determine_onboarding_status(account)
        )
        Rails.logger.info "Updated Connect account status for practice #{practice.id}"
      end
    rescue StandardError => e
      Rails.logger.error "Error handling account.updated: #{e.message}"
    end

    def handle_account_deauthorized(event)
      account_id = event.data.object.id
      practice = find_practice_by_account_id(account_id)

      if practice
        practice.update!(
          stripe_account_id: nil,
          connect_onboarding_status: 'not_started',
          connect_charges_enabled: false,
          connect_payouts_enabled: false,
          connect_details_submitted: false
        )
        Rails.logger.info "Deauthorized Connect account for practice #{practice.id}"
      end
    rescue StandardError => e
      Rails.logger.error "Error handling account.deauthorized: #{e.message}"
    end

    def handle_payment_succeeded(event)
      payment_intent = event.data.object
      practice_id = payment_intent.metadata&.practice_id

      if practice_id
        Rails.logger.info "Payment succeeded for practice #{practice_id}: #{payment_intent.amount_received / 100.0}"
        # Could trigger notifications, update practice balance, etc.
      end
    rescue StandardError => e
      Rails.logger.error "Error handling payment_intent.succeeded: #{e.message}"
    end

    def handle_transfer_created(event)
      transfer = event.data.object
      Rails.logger.info "Transfer created: #{transfer.amount / 100.0} to #{transfer.destination}"
    rescue StandardError => e
      Rails.logger.error "Error handling transfer.created: #{e.message}"
    end

    def find_practice_by_account_id(account_id)
      Practice.find_by(stripe_account_id: account_id)
    end

    # FIXME: this is duplicated into the practice model
    def determine_onboarding_status(account)
      if account.details_submitted && account.charges_enabled && account.payouts_enabled
        'complete'
      elsif account.verification.disabled_reason.present?
        'disabled'
      elsif account.details_submitted
        'pending_review'
      else
        'pending'
      end
    end
  end
end
