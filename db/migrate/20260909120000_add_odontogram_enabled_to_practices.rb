# frozen_string_literal: true

class AddOdontogramEnabledToPractices < ActiveRecord::Migration[8.1]
  def change
    add_column :practices, :odontogram_enabled, :boolean, default: false, null: false
  end
end
