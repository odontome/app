# frozen_string_literal: true

class SubscriptionsController < ApplicationController
  before_action :require_practice_admin
  
  def create
    # Create new Checkout Session for the order
    # See https://stripe.com/docs/api/checkout/sessions/create for more info
    session = nil
    #begin
      session = Stripe::Checkout::Session.create(
        success_url: 'http://localhost:3000' + '/practice/settings/?session_id={CHECKOUT_SESSION_ID}',
        cancel_url: 'http://localhost:3000' + '/practice/settings/',
        payment_method_types: ['card'],
        mode: 'subscription',
        customer_email: current_user.email,
        client_reference_id: current_user.practice_id,
        automatic_tax: { enabled: true },
        line_items: [{
            quantity: 1,
            price: 'price_1JRPagABOdzKVszlVznnsr4Y',
        }],
      )
    # rescue => e
    #   render json: {
    #     error: e,
    #     status: 400
    #   }
    # end
    redirect_to session.url, status: 303
  end

  def update
    portal_session = Stripe::BillingPortal::Session.create({
      customer: current_user.practice.stripe_customer_id,
      return_url: 'http://localhost:3000/practice/settings/',
    })
    redirect_to portal_session.url, status: 303
  end
end