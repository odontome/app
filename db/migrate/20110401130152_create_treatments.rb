class CreateTreatments < ActiveRecord::Migration[5.0]
  def self.up
    create_table :treatments do |t|
      t.integer :practice_id
      t.string :name, limit: 100
      t.float :price

      t.timestamps
    end
  end

  def self.down
    drop_table :treatments
  end
end
