# frozen_string_literal: true

class AddStripePaymentIntentIdToBalances < ActiveRecord::Migration[8.1]
  # One ledger row per Stripe payment; rows entered by hand stay null.
  def change
    add_column :balances, :stripe_payment_intent_id, :string
    add_index :balances, :stripe_payment_intent_id, unique: true
  end
end
