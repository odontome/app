# frozen_string_literal: true

class AnnouncementsController < ApplicationController
  before_action :require_user

  # POST /announcements/dismiss
  def dismiss
    version = params[:version]

    if version.present? && current_user
      # Create dismissed announcement record if it doesn't exist
      DismissedAnnouncement.find_or_create_by(
        user: current_user,
        announcement_version: version.to_i
      )

      head :ok
    else
      head :bad_request
    end
  end
end
