class AddIndexToAppointmentsTable < ActiveRecord::Migration[5.0]
  def self.up
    add_index :appointments, [:starts_at, :ends_at]
  end

  def self.down
    remove_index :appointments, [:starts_at, :ends_at]
  end
end
