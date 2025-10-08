# frozen_string_literal: true

class RemoveProfileImages < ActiveRecord::Migration[7.2]
  def up
    drop_table :profile_images, if_exists: true
    remove_column :practices, :profile_images_count, if_exists: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
