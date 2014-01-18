class RemovePlansTable < ActiveRecord::Migration
  def up
  	drop_table :plans
  end

  def down
  	create_table :plans do |t|
      t.timestamps
    end
  end
end
