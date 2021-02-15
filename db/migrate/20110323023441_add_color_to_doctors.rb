# frozen_string_literal: true

class AddColorToDoctors < ActiveRecord::Migration[5.0]
  def self.up
    change_table :doctors do |t|
      t.string :color, default: '#3366CC', limit: 7
    end
  end

  def self.down
    change_table :doctors do |t|
      t.remove :color
    end
  end
end
