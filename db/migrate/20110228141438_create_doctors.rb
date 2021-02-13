class CreateDoctors < ActiveRecord::Migration[5.0]
  def self.up
    create_table :doctors do |t|
      t.integer :uid
      t.integer :practice_id, null: false
      t.string :firstname, null: false
      t.string :lastname, null: false
      t.string :gender
      t.boolean :is_active, default: true
      t.string :speciality
      t.timestamps
    end
  end

  def self.down
    drop_table :doctors
  end
end
