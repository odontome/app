# frozen_string_literal: true

class SubscriptionsController < ApplicationController
  before_action :require_practice_admin
  skip_before_action :check_subscription_status
  
  def create
    # Create new Checkout Session for the order
    # See https://stripe.com/docs/api/checkout/sessions/create for more info
    session = nil

    begin
      session = Stripe::Checkout::Session.create(
        success_url: request.base_url + '/practice/settings/?session_id={CHECKOUT_SESSION_ID}',
        cancel_url: request.base_url + '/practice/settings/',
        payment_method_types: ['card'],
        mode: 'subscription',
        customer_email: current_user.email,
        client_reference_id: current_user.practice_id,
        automatic_tax: { enabled: true },
        line_items: [{
            quantity: 1,
            price: Rails.configuration.stripe[:price_id],
        }],
      )
    rescue => e
      render json: {
        error: e,
        status: 400
      }
      return
    end
    redirect_to session.url, status: 303, allow_other_host: true
  end

  def update
    portal_session = Stripe::BillingPortal::Session.create({
      customer: current_user.practice.stripe_customer_id,
      return_url: request.base_url + '/practice/settings/',
    })
    redirect_to portal_session.url, status: 303, allow_other_host: true
  end
end