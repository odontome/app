class CreatePatients < ActiveRecord::Migration
  def self.up
    create_table :patients do |t|
      t.integer :uid
      t.integer :practice_id, :null => false
      t.string :firstname, :null => false
      t.string :lastname, :null => false
      t.text :address
      t.string :email
      t.string :telephone
      t.string :mobile
      t.string :emergency_telephone
      t.datetime :date_of_birth, :null => false

      t.timestamps
    end
  end

  def self.down
    drop_table :patients
  end
end
