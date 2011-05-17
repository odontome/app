class AddIndexToAppointmentsTable < ActiveRecord::Migration
  def self.up
    add_index :appointments, [:starts_at, :ends_at]
  end

  def self.down
    remove_index :appointments, [:starts_at, :ends_at]
  end
end
