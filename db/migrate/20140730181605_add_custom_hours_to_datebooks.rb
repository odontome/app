class AddCustomHoursToDatebooks < ActiveRecord::Migration
  def change
    add_column :datebooks, :starts_at, :integer, :default => 8
    add_column :datebooks, :ends_at, :integer, :default => 20
  end
end
