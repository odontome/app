# frozen_string_literal: true

class PaymentsController < ApplicationController
  before_action :require_user, except: %i[pay success failed]
  before_action :find_practice, only: %i[new create]

  def index
    @payments_with_transfers = get_payments_with_transfers

    respond_to do |format|
      format.html # index.html
      format.js
      format.json { render json: @payments_with_transfers }
    end
  end

  # PHASE 1: Clinic creates payment request
  def new
    @patient = Patient.with_practice(current_user.practice_id).find(params[:patient_id])
    @patient_id = @patient.id
  rescue ActiveRecord::RecordNotFound
    # Intentionally suppressing not found error, payments can be created without patients
    @patient_id = nil
  end

  def create
    unless @practice.connect_account_complete?
      flash[:error] = t('stripe_payment_processing.account_not_onboarded')
      render :new
      return
    end

    # Create Payment Intent immediately with clinic-provided data
    amount_cents = (params[:amount].to_f * 100).to_i
    application_fee_cents = (amount_cents * 0.01).to_i # 1% platform fee

    patient = Patient.with_practice(current_user.practice_id).find_by(id: params[:patient_id])

    begin
      flash.clear
      intent = Stripe::PaymentIntent.create({
                                              amount: amount_cents,
                                              currency: params[:currency] || 'usd',
                                              automatic_payment_methods: { enabled: true },
                                              on_behalf_of: @practice.stripe_account_id,
                                              application_fee_amount: application_fee_cents,
                                              transfer_data: {
                                                destination: @practice.stripe_account_id
                                              },
                                              metadata: {
                                                practice_id: @practice.id.to_s,
                                                practice_name: @practice.name,
                                                patient_id: patient&.id&.to_s,
                                                patient_name: params[:patient_name]
                                              }
                                            })

      # Generate shareable payment URL with client_secret
      @payment_url = pay_payment_url(intent.client_secret)
      flash[:success] = t('stripe_payment_processing.link_created_success_message')
      render :qr
    rescue Stripe::StripeError => e
      flash[:error] = t('stripe_payment_processing.link_created_error_message', message: e.message)
      render :new, status: :unprocessable_entity
    end
  end

  # PHASE 2: Patient completes payment (public, no auth)
  def pay
    @client_secret = params[:client_secret].to_s

    # Retrieve payment intent to get patient info and amount
    begin
      @payment_intent = Stripe::PaymentIntent.retrieve(@client_secret.split('_secret_').first)
      raise ActiveRecord::RecordNotFound unless client_secret_matches?(@payment_intent, @client_secret)

      @practice = Practice.find(@payment_intent.metadata.practice_id)
    rescue Stripe::StripeError, ActiveRecord::RecordNotFound
      render :expired, layout: 'simple'
      return
    end

    render layout: 'simple'
  end

  def success
    @payment_intent_id = params[:payment_intent]
    redirect_status = params[:redirect_status]

    if redirect_status.present? && %w[failed canceled requires_payment_method].include?(redirect_status)
      render action: :failed, layout: 'simple'
      return
    end

    unless @payment_intent_id
      render action: :failed, layout: 'simple'
      return
    end

    begin
      @payment_intent = Stripe::PaymentIntent.retrieve(@payment_intent_id)
      unless client_secret_matches?(@payment_intent, params[:payment_intent_client_secret].to_s)
        render action: :failed, layout: 'simple'
        return
      end

      @practice_id = @payment_intent.metadata&.practice_id
      @practice = Practice.find(@practice_id) if @practice_id

      # Extract the latest charge information for receipt
      @latest_charge = @payment_intent.charges.data.first if @payment_intent.charges&.data&.any?

      # Route based on PaymentIntent status
      case @payment_intent.status
      when 'succeeded'
        render layout: 'simple'
      when 'processing', 'requires_action', 'requires_payment_method', 'requires_confirmation', 'canceled'
        render action: :failed, layout: 'simple'
      else
        render action: :failed, layout: 'simple'
      end
    rescue StandardError => e
      render action: :failed, layout: 'simple'
    end
  end

  private

  # The client secret is the only proof the visitor was handed this payment
  # link; the intent id alone appears in URLs and receipts.
  def client_secret_matches?(payment_intent, client_secret)
    client_secret.present? &&
      ActiveSupport::SecurityUtils.secure_compare(payment_intent.client_secret.to_s, client_secret)
  end

  def get_payments_with_transfers
    search_params = {
      query: "metadata['practice_id']:'#{current_user.practice_id}'",
      limit: 25
    }

    # Use Stripe's cursor-based pagination
    # If we have a starting_after parameter, use it for the next page
    search_params[:page] = params[:starting_after] if params[:starting_after].present?

    # Search for payment intents matching our criteria
    search_result = Stripe::PaymentIntent.search(
      search_params,
      { stripe_version: '2020-08-27' }
    )

    # For Connect accounts, filter the results by transfer destination
    payments = if current_user.practice.has_connect_account?
                 search_result.data.select do |payment|
                   payment.transfer_data&.destination == current_user.practice.stripe_account_id
                 end
               else
                 search_result.data
               end

    # Get latest charge information for each payment
    payments_with_transfers = payments.map do |payment|
      latest_charge = nil
      if payment.latest_charge && payment.charges&.data&.any?
        latest_charge = payment.charges.data.find { |charge| charge.id == payment.latest_charge }
      end
      [payment, latest_charge]
    end

    # Set pagination variables for the load more button
    @should_display_load_more = search_result.has_more
    @next_starting_after = search_result.next_page if search_result.has_more

    payments_with_transfers
  rescue Stripe::StripeError => e
    flash.now[:error] = "Unable to retrieve payments: #{e.message}"
    []
  end

  # Payment links are always created for the user's own practice
  def find_practice
    @practice = current_user.practice
  end
end
