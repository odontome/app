# frozen_string_literal: true

class CreateOdontogramEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :odontogram_entries do |t|
      t.references :patient, null: false, foreign_key: true
      t.references :recorded_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.string :recorded_by_name, null: false
      t.string :category, null: false
      t.integer :tooth, null: false
      t.string :surfaces, array: true, default: [], null: false
      t.date :observed_on
      t.timestamps
    end
    add_index :odontogram_entries, [:patient_id, :created_at, :id]
  end
end
