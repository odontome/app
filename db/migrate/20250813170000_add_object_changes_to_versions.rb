class AddObjectChangesToVersions < ActiveRecord::Migration[7.2]
  def change
    add_column :versions, :object_changes, :text, limit: 1_073_741_823
  end
end
