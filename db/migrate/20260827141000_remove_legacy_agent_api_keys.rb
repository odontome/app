# frozen_string_literal: true

class RemoveLegacyAgentApiKeys < ActiveRecord::Migration[8.0]
  def change
    remove_index :practices, :agent_api_key_digest
    remove_columns :practices, :agent_api_key_digest, :agent_api_key_prefix
  end
end
