class AddOdontogramChanges < ActiveRecord::Migration[8.1]
  def change
    add_column :patients, :odontogram_revision, :integer, default: 0, null: false
    add_column :odontogram_entries, :state, :string, default: 'active', null: false

    create_table :odontogram_changes do |t|
      t.references :patient, null: false, foreign_key: true
      t.references :odontogram_entry, null: false, foreign_key: { on_delete: :cascade }
      t.references :recorded_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.string :recorded_by_name, null: false
      t.string :request_id, null: false
      t.string :editor_id, null: false
      t.string :request_digest, null: false
      t.string :operation, null: false
      t.integer :revision, null: false
      t.bigint :reverses_id
      t.jsonb :before_state
      t.jsonb :after_state, null: false
      t.timestamps
    end
    add_index :odontogram_changes, [:patient_id, :request_id], unique: true
    add_index :odontogram_changes, [:patient_id, :revision], unique: true
    add_index :odontogram_changes, :reverses_id, unique: true
  end
end
