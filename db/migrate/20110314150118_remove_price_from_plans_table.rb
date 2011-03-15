class RemovePriceFromPlansTable < ActiveRecord::Migration
  def self.up
    change_table :plans do |t|
      t.remove :price
    end
  end

  def self.down
    change_table :plans do |t|
      t.column :price, :decimal, :precision => 4, :scale => 2, :null => true
    end
  end
end
