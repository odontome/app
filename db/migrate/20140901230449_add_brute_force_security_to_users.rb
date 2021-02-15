# frozen_string_literal: true

class AddBruteForceSecurityToUsers < ActiveRecord::Migration[5.0]
  def change
    add_column :users, :failed_login_count, :integer, default: 0
  end
end
