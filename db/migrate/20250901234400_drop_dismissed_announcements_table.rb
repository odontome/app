# frozen_string_literal: true

class DropDismissedAnnouncementsTable < ActiveRecord::Migration[7.2]
  def up
    drop_table :dismissed_announcements
  end

  def down
    create_table :dismissed_announcements do |t|
      t.bigint :user_id, null: false
      t.integer :announcement_version, null: false
      t.timestamps
    end
    
    add_index :dismissed_announcements, [:user_id, :announcement_version], unique: true, name: 'index_dismissed_announcements_on_user_and_version'
    add_foreign_key :dismissed_announcements, :users
  end
end