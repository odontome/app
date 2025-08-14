class AddPracticeIdToVersions < ActiveRecord::Migration[7.2]
  def change
    add_column :versions, :practice_id, :integer
    add_index :versions, :practice_id
    add_index :versions, [:practice_id, :created_at]
  end
end
