class AddCancelledAtToPractices < ActiveRecord::Migration
  def self.up
    change_table :practices do |t|
      t.datetime :cancelled_at
    end
  end

  def self.down
    remove_column :practices, :cancelled_at
  end
end
