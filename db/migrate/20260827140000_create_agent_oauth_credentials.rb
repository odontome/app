# frozen_string_literal: true

class CreateAgentOauthCredentials < ActiveRecord::Migration[8.0]
  def change
    create_table :agent_oauth_authorizations do |t|
      t.references :user, null: false, foreign_key: true
      t.references :practice, null: false, foreign_key: true
      t.string :code_digest, null: false
      t.string :client_id, null: false
      t.string :redirect_uri, null: false
      t.string :code_challenge, null: false
      t.string :resource, null: false
      t.datetime :expires_at, null: false
      t.datetime :consumed_at
      t.timestamps
    end
    add_index :agent_oauth_authorizations, :code_digest, unique: true

    create_table :agent_oauth_access_tokens do |t|
      t.references :user, null: false, foreign_key: true
      t.references :practice, null: false, foreign_key: true
      t.string :token_digest, null: false
      t.string :resource, null: false
      t.datetime :expires_at, null: false
      t.datetime :revoked_at
      t.timestamps
    end
    add_index :agent_oauth_access_tokens, :token_digest, unique: true
  end
end
