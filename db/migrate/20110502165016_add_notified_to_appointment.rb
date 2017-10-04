class AddNotifiedToAppointment < ActiveRecord::Migration[5.0]
  def self.up
    change_table :appointments do |t|
      t.boolean :notified, :default => false
    end
  end

  def self.down
    remove_column :appointments, :notified
  end
end
