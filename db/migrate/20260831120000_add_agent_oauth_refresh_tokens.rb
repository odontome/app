# frozen_string_literal: true

class AddAgentOauthRefreshTokens < ActiveRecord::Migration[8.1]
  def change
    add_column :agent_oauth_authorizations, :refresh_allowed, :boolean, null: false, default: false
    add_reference :agent_oauth_access_tokens, :agent_oauth_authorization,
                  foreign_key: { on_delete: :cascade }
    add_column :agent_oauth_access_tokens, :refresh_token_digest, :string
    add_column :agent_oauth_access_tokens, :refresh_expires_at, :datetime
    add_column :agent_oauth_access_tokens, :refresh_consumed_at, :datetime
    add_index :agent_oauth_access_tokens, :refresh_token_digest, unique: true
  end
end
