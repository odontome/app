# frozen_string_literal: true

class AddAgentAccessToPractices < ActiveRecord::Migration[8.0]
  def change
    add_column :practices, :agent_access_enabled, :boolean, default: false, null: false
    add_column :practices, :agent_api_key_digest, :string
    add_column :practices, :agent_label, :string, default: 'Agent'

    add_index :practices, :agent_api_key_digest, unique: true
  end
end
