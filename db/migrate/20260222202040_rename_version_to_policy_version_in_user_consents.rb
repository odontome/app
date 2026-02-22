# frozen_string_literal: true

class RenameVersionToPolicyVersionInUserConsents < ActiveRecord::Migration[8.0]
  def change
    rename_column :user_consents, :version, :policy_version
  end
end
