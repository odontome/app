class MarkAllAppointmentsAsNotifiedOfSchedule < ActiveRecord::Migration[5.0]
  def up
    Appointment.update_all notified_of_schedule: true
  end

  def down
    Appointment.update_all notified_of_schedule: false
  end
end
