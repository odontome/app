class AddDefaultValueToStatusInAppointments < ActiveRecord::Migration[5.0]
  def self.up
    change_column :appointments, :status, :string, default: Appointment.status[:confirmed]

    # mark all previously created appointments to match
    # out newly created default value
    Appointment.update_all status: Appointment.status[:confirmed]
  end

  def self.down
    change_column :appointments, :status, :string, default: ''
  end
end
