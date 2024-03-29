# frozen_string_literal: true

class CreatePatientCommunications < ActiveRecord::Migration[5.0]
  def change
    create_table :patient_communications do |t|
      t.string :subject
      t.string :message
      t.integer :number_of_patients
      t.integer :user_id
      t.timestamps
    end
  end
end
