# frozen_string_literal: true

class AddActivitySourceToVersions < ActiveRecord::Migration[8.1]
  def change
    add_column :versions, :activity_source, :string
  end
end
