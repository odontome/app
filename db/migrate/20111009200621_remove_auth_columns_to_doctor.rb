class RemoveAuthColumnsToDoctor < ActiveRecord::Migration[5.0]
  def self.up
    remove_column :doctors, :persistence_token
    remove_column :doctors, :crypted_password
    remove_column :doctors, :password_salt
    remove_column :doctors, :single_access_token
    remove_column :doctors, :current_login_at
    remove_column :doctors, :last_login_at
    remove_column :doctors, :login_count
  end

  def self.down
    change_table :doctors do |t|
      t.string    :crypted_password
      t.string    :password_salt
      t.string    :persistence_token
      t.string    :single_access_token
      t.datetime  :current_login_at
      t.datetime  :last_login_at
      t.integer   :login_count, null: false, default: 0
    end
  end
end
