class SetDefaultPatientsToPractice < ActiveRecord::Migration[5.0]
  def self.up
    change_table :practices do |t|
      t.change :number_of_patients, :integer, :default => 500
    end
  end

  def self.down
    change_table :practices do |t|
      t.change :number_of_patients, :integer, :default => nil
    end
  end
end
