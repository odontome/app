class AddMedicalHistoryToPatient < ActiveRecord::Migration[5.0]
  def self.up
    change_table :patients do |t|
      t.text :allergies
      t.text :past_illnesses
      t.text :surgeries
      t.text :medications
      t.string :cigarettes_per_day
      t.string :drinks_per_day
      t.text :drugs_use
      t.text :family_diseases
    end
  end

  def self.down
    remove_column :patients, :allergies
    remove_column :patients, :past_illnesses
    remove_column :patients, :surgeries
    remove_column :patients, :medications
    remove_column :patients, :cigarettes_per_day
    remove_column :patients, :drinks_per_day
    remove_column :patients, :drugs_use
    remove_column :patients, :family_diseases
  end
end
