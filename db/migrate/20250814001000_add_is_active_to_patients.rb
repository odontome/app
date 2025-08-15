# frozen_string_literal: true

class AddIsActiveToPatients < ActiveRecord::Migration[7.2]
  def change
    add_column :patients, :is_active, :boolean, default: true
  end
end