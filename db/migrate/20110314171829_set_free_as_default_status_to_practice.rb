class SetFreeAsDefaultStatusToPractice < ActiveRecord::Migration
  def self.up
    change_table :practices do |t|
      t.change :status, :string, :limit => 50, :default => "free"
      Practice.connection.execute('update practices set status="free" where status="unconfirmed"')
    end
  end

  def self.down
    change_table :practices do |t|
      t.change :status, :string, :limit => 50, :default => "unconfirmed"
      Practice.connection.execute('update practices set status="unconfirmed" where status="free"')
    end
  end
end
