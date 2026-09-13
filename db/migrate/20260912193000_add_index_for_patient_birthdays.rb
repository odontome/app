# frozen_string_literal: true

class AddIndexForPatientBirthdays < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :patients,
              'practice_id, EXTRACT(MONTH FROM date_of_birth), EXTRACT(DAY FROM date_of_birth)',
              name: 'index_patients_on_practice_id_and_birthday',
              algorithm: :concurrently
  end
end
