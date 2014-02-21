class AddScheduledAndDeliveredFlagsToAppointments < ActiveRecord::Migration
  def change
  	rename_column :appointments, :notified, :notified_of_reminder
	add_column :appointments, :notified_of_schedule, :boolean, :default => false
  end
end
