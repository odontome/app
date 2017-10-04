class ChangeDateOfBirthToDateInPatients < ActiveRecord::Migration[5.0]
  def self.up
    change_column :patients, :date_of_birth, :date
  end

  def self.down
    change_column :patients, :date_of_birth, :datetime
  end
end