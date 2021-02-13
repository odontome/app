class RemovePlansTable < ActiveRecord::Migration[5.0]
  def up
    drop_table :plans
  end

  def down
    create_table :plans do |t|
      t.timestamps
    end
  end
end
