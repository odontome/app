# frozen_string_literal: true

class CreateDismissedAnnouncements < ActiveRecord::Migration[7.2]
  def change
    create_table :dismissed_announcements do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :announcement_version, null: false
      t.timestamps
    end

    add_index :dismissed_announcements, [:user_id, :announcement_version], 
              unique: true, name: 'index_dismissed_announcements_on_user_and_version'
  end
end