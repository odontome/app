# frozen_string_literal: true

class AnnouncementsController < ApplicationController
  before_action :require_user

  # POST /announcements/dismiss
  def dismiss
    version = params[:version]

    if version.present? && current_user
      # Find the announcement by version
      announcement = Announcement.find_by(version: version.to_i)
      
      if announcement
        # Create dismissed announcement record if it doesn't exist
        AnnouncementDismissal.find_or_create_by(
          user: current_user,
          announcement: announcement
        )
        head :ok
      else
        head :not_found
      end
    else
      head :bad_request
    end
  end
end
