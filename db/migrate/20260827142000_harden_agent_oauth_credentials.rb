# frozen_string_literal: true

class HardenAgentOauthCredentials < ActiveRecord::Migration[8.0]
  def change
    change_column_null :agent_oauth_authorizations, :code_digest, true
    add_column :agent_oauth_authorizations, :approval_token_digest, :string, null: false
    add_column :agent_oauth_authorizations, :state, :text
    add_column :agent_oauth_authorizations, :approved_at, :datetime

    remove_foreign_key :agent_oauth_authorizations, :users
    remove_foreign_key :agent_oauth_authorizations, :practices
    remove_foreign_key :agent_oauth_access_tokens, :users
    remove_foreign_key :agent_oauth_access_tokens, :practices

    add_foreign_key :agent_oauth_authorizations, :users, on_delete: :cascade
    add_foreign_key :agent_oauth_authorizations, :practices, on_delete: :cascade
    add_foreign_key :agent_oauth_access_tokens, :users, on_delete: :cascade
    add_foreign_key :agent_oauth_access_tokens, :practices, on_delete: :cascade
  end
end
