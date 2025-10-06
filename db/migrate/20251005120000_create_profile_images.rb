# frozen_string_literal: true

class CreateProfileImages < ActiveRecord::Migration[7.2]
  def change
    create_table :profile_images do |t|
      t.references :practice, null: false, foreign_key: true
      t.references :imageable, polymorphic: true, null: false, index: false
      t.string :file_url, null: false

      t.timestamps
    end

    add_index :profile_images, %i[practice_id file_url]
    add_index :profile_images, %i[imageable_type imageable_id], unique: true

    add_column :practices, :profile_images_count, :integer, default: 0, null: false

    remove_column :doctors, :profile_picture_url, :string
  end
end
