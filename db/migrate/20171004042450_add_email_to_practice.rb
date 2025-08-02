# frozen_string_literal: true

class AddEmailToPractice < ActiveRecord::Migration[5.1]
  def up
    add_column :practices, :email, :string
    Practice.update_all('email = (SELECT email FROM users
      WHERE practice_id = practices.id
      ORDER BY id ASC LIMIT 1)')
  end

  def down
    remove_column :practices, :email
  end
end
