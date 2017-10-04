class UpdatePatientCommunicationsTable < ActiveRecord::Migration[5.0]
  def up
    rename_column :patient_communications, :number_of_patients, :number_of_recipients
    add_column :patient_communications, :number_of_opens, :integer, default: 0
    rename_table :patient_communications, :broadcasts
  end

  def down
    rename_column :broadcasts, :number_of_recipients, :number_of_patients
    remove_column :broadcasts, :number_of_opens
    rename_table :broadcasts, :patient_communications
  end
end
