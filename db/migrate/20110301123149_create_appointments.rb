class CreateAppointments < ActiveRecord::Migration[5.0]
  def self.up
    create_table :appointments do |t|
      t.integer :practice_id, null: false
      t.integer :doctor_id, null: false
      t.integer :patient_id, null: false
      t.string :notes, limit: 255
      t.string :status, limit: 50
      t.datetime :starts_at
      t.datetime :ends_at

      t.timestamps
    end
  end

  def self.down
    drop_table :appointments
  end
end
