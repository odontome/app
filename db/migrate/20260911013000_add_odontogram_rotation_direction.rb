class AddOdontogramRotationDirection < ActiveRecord::Migration[8.1]
  def change
    add_column :odontogram_entries, :rotation_direction, :string
  end
end
