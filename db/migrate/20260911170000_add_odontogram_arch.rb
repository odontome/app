class AddOdontogramArch < ActiveRecord::Migration[8.1]
  def change
    add_column :odontogram_entries, :arch, :string
  end
end
