class UpdateCountersInPractices < ActiveRecord::Migration[5.0]
  def up
    remove_column :practices, :appointments_count
    add_column :practices, :datebooks_count, :integer
  end

  def down
    remove_column :practices, :datebooks_count
    add_column :practices, :appointments_count, :integer
  end
end
