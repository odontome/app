class AddColorToDoctors < ActiveRecord::Migration
  def self.up
    change_table :doctors do |t|
      t.string :color, :default => "#3366CC", :limit => 7
    end
  end

  def self.down
    change_table :doctors do |t|
      t.remove :color
    end
  end
end
