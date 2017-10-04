class AddEmailToDoctors < ActiveRecord::Migration[5.0]
  def self.up
    change_table :doctors do |t|
      t.string :email
    end
  end

  def self.down
    remove_column :doctors, :email
  end
end
