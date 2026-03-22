# frozen_string_literal: true

class AddIndexForFutureAppointmentLookup < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  INDEX_NAME = 'index_appointments_on_patient_id_and_starts_at_not_cancelled'.freeze

  def up
    return if index_exists?(:appointments, name: INDEX_NAME)

    add_index :appointments,
              %i[patient_id starts_at],
              name: INDEX_NAME,
              where: "status != 'cancelled'",
              algorithm: :concurrently
  end

  def down
    return unless index_exists?(:appointments, name: INDEX_NAME)

    remove_index :appointments, name: INDEX_NAME
  end
end
