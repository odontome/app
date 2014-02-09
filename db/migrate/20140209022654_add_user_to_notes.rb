class AddUserToNotes < ActiveRecord::Migration
  def up
  	add_column :notes, :user_id, :integer
  end

  def down
  	remove_column :notes, :user_id
  end
end
