class UpdateCountersInPractices < ActiveRecord::Migration
  def up
  	remove_column :practices, :appointments_count
  	add_column :practices, :datebooks_count, :interger
  end

  def down
  	remove_column :practices, :datebooks_count
  	add_column :practices, :appointments_count, :interger
  end
end