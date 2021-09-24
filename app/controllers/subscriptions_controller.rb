# frozen_string_literal: true

class SubscriptionsController < ApplicationController
  before_action :require_practice_admin
  
  def create
    # Create new Checkout Session for the order
    # See https://stripe.com/docs/api/checkout/sessions/create for more info
    session = nil
    #begin
      session = Stripe::Checkout::Session.create(
        success_url: 'https://localhost:3000' + '/practice/?session_id={CHECKOUT_SESSION_ID}',
        cancel_url: 'https://localhost:3000' + '/practice/',
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
    puts "*************"
  puts session
    redirect_to session.url, status: 303
  end
end