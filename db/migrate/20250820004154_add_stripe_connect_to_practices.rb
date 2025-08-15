# frozen_string_literal: true

class AddStripeConnectToPractices < ActiveRecord::Migration[7.2]
  def change
    add_column :practices, :stripe_account_id, :text
    add_column :practices, :connect_onboarding_status, :string, default: 'not_started'
    add_column :practices, :connect_charges_enabled, :boolean, default: false
    add_column :practices, :connect_payouts_enabled, :boolean, default: false
    add_column :practices, :connect_details_submitted, :boolean, default: false
    
    add_index :practices, :stripe_account_id
    add_index :practices, :connect_onboarding_status
  end
end