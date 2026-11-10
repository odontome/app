# frozen_string_literal: true

class AddStripePaymentIntentIdToBalances < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  # Stripe can deliver the same payment event more than once. The unique index
  # keeps the ledger to one row per payment; rows entered by hand stay null.
  def change
    add_column :balances, :stripe_payment_intent_id, :string
    add_index :balances, :stripe_payment_intent_id, unique: true, algorithm: :concurrently
  end
end
