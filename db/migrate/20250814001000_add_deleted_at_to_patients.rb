# frozen_string_literal: true

class AddDeletedAtToPatients < ActiveRecord::Migration[7.2]
  def change
    add_column :patients, :deleted_at, :timestamp
    add_index :patients, :deleted_at
  end
end
