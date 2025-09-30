# frozen_string_literal: true

class AddDeletedAtToPatients < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def up
    add_column :patients, :deleted_at, :datetime unless column_exists?(:patients, :deleted_at)

    return unless column_exists?(:patients, :deleted_at)
    return if index_exists?(:patients, :deleted_at)

    add_index :patients, :deleted_at, algorithm: :concurrently
  end

  def down
    remove_index :patients, column: :deleted_at if index_exists?(:patients, :deleted_at)
    remove_column :patients, :deleted_at if column_exists?(:patients, :deleted_at)
  end
end
