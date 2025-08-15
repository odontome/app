# frozen_string_literal: true

class PaymentsController < ApplicationController
  before_action :require_user
  before_action :find_practice, only: [:new, :create]

  def new
    @practice = Practice.find(params[:practice_id])
    @amount = params[:amount]&.to_f || 100.00 # Default amount for demo
    
    unless @practice.connect_account_complete?
      flash[:error] = "This practice is not yet ready to accept payments."
      redirect_to practice_path
      return
    end
  end

  def create
    @practice = Practice.find(params[:practice_id])
    amount_cents = (params[:amount].to_f * 100).to_i
    application_fee_cents = (amount_cents * 0.05).to_i # 5% platform fee for demo
    
    unless @practice.connect_account_complete?
      render json: { error: "Practice not ready to accept payments" }, status: 400
      return
    end

    begin
      # Create Payment Intent with application fee
      intent = Stripe::PaymentIntent.create({
        amount: amount_cents,
        currency: 'usd',
        application_fee_amount: application_fee_cents,
        transfer_data: {
          destination: @practice.stripe_account_id,
        },
        metadata: {
          practice_id: @practice.id.to_s,
          practice_name: @practice.name,
          patient_name: params[:patient_name] || "Demo Patient"
        }
      })

      render json: { 
        client_secret: intent.client_secret,
        amount: amount_cents,
        application_fee: application_fee_cents
      }
    rescue Stripe::StripeError => e
      render json: { error: e.message }, status: 400
    end
  end

  def success
    @payment_intent_id = params[:payment_intent]
    
    if @payment_intent_id
      begin
        @payment_intent = Stripe::PaymentIntent.retrieve(@payment_intent_id)
        @practice_id = @payment_intent.metadata&.practice_id
        @practice = Practice.find(@practice_id) if @practice_id
      rescue Stripe::StripeError => e
        flash[:error] = "Payment verification failed: #{e.message}"
      end
    end
  end

  private

  def find_practice
    @practice = Practice.find(params[:practice_id])
  rescue ActiveRecord::RecordNotFound
    flash[:error] = "Practice not found"
    redirect_to root_path
  end
end