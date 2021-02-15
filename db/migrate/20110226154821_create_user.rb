# frozen_string_literal: true

class CreateUser < ActiveRecord::Migration[5.0]
  def self.up
    create_table :users do |t|
      t.string :firstname, null: false
      t.string :lastname, null: false
      t.string :email, null: false
      t.string :crypted_password, null: false
      t.string :password_salt
      t.string :persistence_token
      t.string :roles, default: 'user', null: false
      t.integer :practice_id

      t.timestamps
    end
  end

  def self.down
    drop_table :users
  end
end
