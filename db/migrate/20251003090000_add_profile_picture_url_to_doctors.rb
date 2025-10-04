# frozen_string_literal: true

class AddProfilePictureUrlToDoctors < ActiveRecord::Migration[7.0]
  def change
    add_column :doctors, :profile_picture_url, :string
  end
end
