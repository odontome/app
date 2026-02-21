class AddAgentApiKeyPrefixToPractices < ActiveRecord::Migration[8.0]
  def change
    add_column :practices, :agent_api_key_prefix, :string
  end
end
