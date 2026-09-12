class AddOdontogramMobilityDetails < ActiveRecord::Migration[8.1]
  def change
    add_column :odontogram_entries, :mobility_grade, :string, limit: 10
    add_column :odontogram_entries, :mobility_scale, :string, limit: 60
  end
end
