# frozen_string_literal: true

class RemoveBroadcastsTable < ActiveRecord::Migration[5.2]
  def change
    drop_table :broadcasts
  end
end
