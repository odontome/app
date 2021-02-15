# frozen_string_literal: true

class AddNotifiedForReviewToAppointments < ActiveRecord::Migration[5.0]
  def self.up
    change_table :appointments do |t|
      t.boolean :notified_of_review, default: false
    end

    # mark all previously created appointments as "notified"
    # we do this to prevent a massive spam to our user base
    Appointment.update_all notified_of_review: true
  end

  def self.down
    remove_column :appointments, :notified_of_review
  end
end
