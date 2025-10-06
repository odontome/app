# frozen_string_literal: true

class RemoveDuplicateProfileImagesIndex < ActiveRecord::Migration[7.2]
  def change
    remove_index :profile_images, name: :index_profile_images_on_imageable, if_exists: true
  end
end
