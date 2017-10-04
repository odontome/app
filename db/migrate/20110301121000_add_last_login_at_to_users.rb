class AddLastLoginAtToUsers < ActiveRecord::Migration[5.0]
  def self.up
    change_table :users do |t|
      t.datetime :current_login_at
      t.datetime :last_login_at
      t.integer :login_count, :null => false, :default => 0
    end
  end

  def self.down
    remove_column :users, :last_login_at
    remove_column :users, :login_count
    remove_column :users, :current_login_at
  end
end

