# frozen_string_literal: true

class RemoveAuthlogicColumnsFromUsers < ActiveRecord::Migration[5.2]
  def change
    remove_column :users, :crypted_password, :string
    remove_column :users, :password_salt, :string
    remove_column :users, :persistence_token, :string
    remove_column :users, :authentication_token, :string
    remove_column :users, :login_count, :integer
  end
end
