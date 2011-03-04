class CreatePlansWithFreePlan < ActiveRecord::Migration
  def self.up
    create_table :plans do |t|
      t.integer :number_of_patients, :null => false
      t.decimal :price, :precision => 4, :scale => 2, :null => false

      t.timestamps
    end
    change_table :practices do |t|
      t.integer :plan_id, :null => false, :default => 1
    end
    plan = Plan.create!(:number_of_patients => 500, :price => 9.99)
  end
  def self.down
    drop_table :plans
    remove_column :practices, :plan_id
    plan = Plan.find(1)
    plan.destroy
  end
end
