class ChangeUidToStringInAllTables < ActiveRecord::Migration[5.0]
  def self.up
    change_table :patients do |t|
      t.change :uid, :string
    end
    change_table :doctors do |t|
      t.change :uid, :string
    end
  end

  def self.down
    change_table :patients do |t|
      t.change :uid, :integer
    end
    change_table :doctors do |t|
      t.change :uid, :integer
    end
  end
end
