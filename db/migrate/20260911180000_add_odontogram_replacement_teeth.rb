class AddOdontogramReplacementTeeth < ActiveRecord::Migration[8.1]
  def change
    add_column :odontogram_entries, :replacement_teeth, :integer, array: true, default: [], null: false
  end
end
