class SetDefaultPatientsToPractice < ActiveRecord::Migration
  def self.up
    change_table :practices do |t|
      t.change :number_of_patients, :integer, :default => PLANS['free']['number_of_patients'].to_i
    end
  end

  def self.down
    change_table :practices do |t|
      t.change :number_of_patients, :integer, :default => nil
    end
  end
end
