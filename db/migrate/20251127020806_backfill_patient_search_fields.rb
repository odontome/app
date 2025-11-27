# frozen_string_literal: true

class BackfillPatientSearchFields < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    Patient.where(firstname_initial: nil).or(Patient.where(fullname_search: nil)).find_each do |patient|
      patient.send(:assign_firstname_initial)
      patient.send(:set_fullname_search)
      patient.save!(validate: false)
    end
  end

  def down
    # No rollback needed - these fields should always be populated
  end
end
