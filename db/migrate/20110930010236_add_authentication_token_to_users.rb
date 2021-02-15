# frozen_string_literal: true

class AddAuthenticationTokenToUsers < ActiveRecord::Migration[5.0]
  def self.up
    add_column :users, :authentication_token, :string
  end

  def self.down
    remove_column :users, :authentication_token
  end
end
