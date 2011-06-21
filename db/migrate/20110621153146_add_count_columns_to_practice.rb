class AddCountColumnsToPractice < ActiveRecord::Migration
  def self.up
    change_table :practices do |t|
      t.integer :patients_count, :default => 0
      t.integer :appointments_count, :default => 0
      t.integer :doctors_count, :default => 0
      t.integer :users_count, :default => 0
    end
    Practice.reset_column_information
    Practice.find(:all).each do |p| 
       Practice.update_counters p.id, :patients_count => p.patients.count
       Practice.update_counters p.id, :appointments_count => p.appointments.count
       Practice.update_counters p.id, :doctors_count => p.doctors.count
       Practice.update_counters p.id, :users_count => p.users.count
     end
    
  end

  def self.down
    remove_column :practices, :users_count
    remove_column :practices, :doctors_count
    remove_column :practices, :appointments_count
    remove_column :practices, :patients_count
  end
end
