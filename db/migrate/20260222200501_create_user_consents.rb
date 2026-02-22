# frozen_string_literal: true

class CreateUserConsents < ActiveRecord::Migration[8.0]
  def change
    create_table :user_consents do |t|
      t.references :user, null: false, foreign_key: true
      t.references :practice, null: false, foreign_key: true
      t.string :consent_type, null: false
      t.string :version, null: false
      t.datetime :accepted_at, null: false
      t.string :ip_address
      t.string :user_agent
      t.timestamps
    end

    add_index :user_consents, [:user_id, :consent_type, :version], unique: true
  end
end
