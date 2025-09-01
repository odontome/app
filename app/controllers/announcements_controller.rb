# frozen_string_literal: true

class AnnouncementsController < ApplicationController
  before_action :require_user

  # POST /announcements/dismiss
  def dismiss
    version = params[:version]

    if version.present?
      dismissed_announcements = session[:dismissed_announcements] || []
      dismissed_announcements << version.to_i unless dismissed_announcements.include?(version.to_i)
      session[:dismissed_announcements] = dismissed_announcements

      head :ok
    else
      head :bad_request
    end
  end
end
