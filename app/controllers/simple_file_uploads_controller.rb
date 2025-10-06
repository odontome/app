# frozen_string_literal: true

class SimpleFileUploadsController < ApplicationController
  before_action :require_user

  def destroy
    file_url = params[:file_url].to_s.strip

    if file_url.blank?
      head :bad_request
      return
    end

    delete_remote_asset(file_url)
    clear_database_associations(file_url)
    head :no_content
  end

  private

  def delete_remote_asset(file_url)
    SimpleFileUpload::DeleteFile.new(file_url: file_url).call
  end

  def clear_database_associations(file_url)
    practice_id = current_user&.practice_id
    return unless practice_id

    profile_image = ProfileImage.find_by(practice_id: practice_id, file_url: file_url)
    profile_image&.destroy
  end
end
