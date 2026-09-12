class AddOdontogramMemberTeeth < ActiveRecord::Migration[8.1]
  def change
    add_column :odontogram_entries, :member_teeth, :integer, array: true, default: [], null: false
    add_index :odontogram_entries, :member_teeth, using: :gin
  end
end
