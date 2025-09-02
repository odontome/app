# frozen_string_literal: true

class MigrateDismissedAnnouncementsToAnnouncementDismissals < ActiveRecord::Migration[7.2]
  def up
    # Migrate existing dismissed announcements to the new join table structure
    DismissedAnnouncement.find_each do |dismissed|
      # Find the corresponding announcement
      announcement = Announcement.find_by(version: dismissed.announcement_version)
      next unless announcement
      
      # Create the dismissal relationship
      AnnouncementDismissal.find_or_create_by(
        user: dismissed.user,
        announcement: announcement
      )
    end
  end

  def down
    # Remove all announcement dismissals
    AnnouncementDismissal.delete_all
  end
end