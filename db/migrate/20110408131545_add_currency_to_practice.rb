# frozen_string_literal: true

class AddCurrencyToPractice < ActiveRecord::Migration[5.0]
  def self.up
    change_table :practices do |t|
      t.string :currency_unit, default: '$'
    end
  end

  def self.down
    remove_column :practices, :currency_unit
  end
end
