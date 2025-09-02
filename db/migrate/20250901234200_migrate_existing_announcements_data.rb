# frozen_string_literal: true

class MigrateExistingAnnouncementsData < ActiveRecord::Migration[7.2]
  def up
    # Migrate existing announcements from YAML to database
    existing_announcements = [
      { version: 1, i18n_key: "announcements.v1.message", announcement_type: "info", active: true, published_at: Time.current }
    ]
    
    existing_announcements.each do |announcement_data|
      Announcement.create!(announcement_data)
    end
  end

  def down
    # Remove migrated announcements
    Announcement.where(version: [1]).delete_all
  end
end