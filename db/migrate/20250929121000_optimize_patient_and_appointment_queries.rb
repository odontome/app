# frozen_string_literal: true

class OptimizePatientAndAppointmentQueries < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def up
    enable_extension 'pg_trgm' unless extension_enabled?('pg_trgm')

    add_index :patients, :practice_id, algorithm: :concurrently unless index_exists?(:patients, :practice_id)
    unless index_name_exists?(:patients, 'index_patients_on_lower_uid_trgm')
      add_index :patients,
                'lower(uid) gin_trgm_ops',
                using: :gin,
                name: 'index_patients_on_lower_uid_trgm',
                algorithm: :concurrently
    end

    unless index_name_exists?(:patients, 'index_patients_on_fullname_trgm')
      add_index :patients,
                "lower(firstname || ' ' || lastname) gin_trgm_ops",
                using: :gin,
                name: 'index_patients_on_fullname_trgm',
                algorithm: :concurrently
    end

    add_index :appointments, :doctor_id, algorithm: :concurrently unless index_exists?(:appointments, :doctor_id)
    return if index_name_exists?(:appointments, 'index_appointments_on_datebook_id_and_times')

    add_index :appointments,
              %i[datebook_id starts_at ends_at],
              algorithm: :concurrently,
              name: 'index_appointments_on_datebook_id_and_times'
  end

  def down
    remove_index :appointments, name: 'index_appointments_on_datebook_id_and_times' if index_name_exists?(:appointments,
                                                                                                          'index_appointments_on_datebook_id_and_times')
    remove_index :appointments, column: :doctor_id if index_exists?(:appointments, :doctor_id)

    remove_index :patients, name: 'index_patients_on_fullname_trgm' if index_name_exists?(:patients,
                                                                                          'index_patients_on_fullname_trgm')
    remove_index :patients, name: 'index_patients_on_lower_uid_trgm' if index_name_exists?(:patients,
                                                                                           'index_patients_on_lower_uid_trgm')
    remove_index :patients, column: :practice_id if index_exists?(:patients, :practice_id)
  end
end
