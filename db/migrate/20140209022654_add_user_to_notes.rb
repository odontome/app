class AddUserToNotes < ActiveRecord::Migration[5.0]
  def up
    add_column :notes, :user_id, :integer
  end

  def down
    remove_column :notes, :user_id
  end
end
