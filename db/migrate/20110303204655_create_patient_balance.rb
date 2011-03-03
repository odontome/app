class CreatePatientBalance < ActiveRecord::Migration
  def self.up
    create_table :balances do |t|
      t.integer :patient_id
      t.float :amount
      t.string :notes

      t.timestamps
    end
  end

  def self.down
    drop_table :balances
  end
end
