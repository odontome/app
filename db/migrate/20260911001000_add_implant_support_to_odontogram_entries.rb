class AddImplantSupportToOdontogramEntries < ActiveRecord::Migration[8.1]
  def change
    add_reference :odontogram_entries, :implant_entry, foreign_key: { to_table: :odontogram_entries }
  end
end
