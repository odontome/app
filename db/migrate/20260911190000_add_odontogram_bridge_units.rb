class AddOdontogramBridgeUnits < ActiveRecord::Migration[8.1]
  def change
    add_column :odontogram_entries, :bridge_units, :jsonb, default: [], null: false
  end
end
