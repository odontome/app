# frozen_string_literal: true

class AddIndexForPatientLastVisitLookup < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  INDEX_NAME = 'index_appointments_on_patient_id_and_ends_at_confirmed'.freeze

  def up
    return if index_exists?(:appointments, name: INDEX_NAME)

    add_index :appointments,
              %i[patient_id ends_at],
              name: INDEX_NAME,
              order: { ends_at: :desc },
              where: "status = 'confirmed'",
              algorithm: :concurrently
  end

  def down
    return unless index_exists?(:appointments, name: INDEX_NAME)

    remove_index :appointments, name: INDEX_NAME
  end
end
