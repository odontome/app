# frozen_string_literal: true

class AddScheduledAndDeliveredFlagsToAppointments < ActiveRecord::Migration[5.0]
  def change
    rename_column :appointments, :notified, :notified_of_reminder
    add_column :appointments, :notified_of_schedule, :boolean, default: false
  end
end
