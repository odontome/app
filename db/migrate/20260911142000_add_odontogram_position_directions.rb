class AddOdontogramPositionDirections < ActiveRecord::Migration[8.1]
  def change
    add_column :odontogram_entries, :position_directions, :string, array: true, default: [], null: false
  end
end
