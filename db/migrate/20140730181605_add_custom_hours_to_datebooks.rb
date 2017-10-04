class AddCustomHoursToDatebooks < ActiveRecord::Migration[5.0]
  def change
    add_column :datebooks, :starts_at, :integer, :default => 8
    add_column :datebooks, :ends_at, :integer, :default => 20
  end
end
