# frozen_string_literal: true

class ProfileImage < ApplicationRecord
  MAX_PER_PRACTICE = 500
  MAX_WITHOUT_SUBSCRIPTION = 5

  attr_reader :file_url_for_deletion

  belongs_to :practice, counter_cache: true
  belongs_to :imageable, polymorphic: true

  validates :file_url, presence: true
  validates :practice, presence: true
  validates :imageable, presence: true
  validate :enforce_practice_upload_limit, on: :create

  before_destroy :cache_file_url_for_deletion
  after_destroy_commit :delete_remote_asset

  private

  attr_writer :file_url_for_deletion

  def enforce_practice_upload_limit
    return if practice.blank?

    limit = upload_limit_for_practice
    current_count = practice.profile_images_count.to_i
    return unless current_count >= limit

    delete_pending_upload
    error_key = limit == MAX_PER_PRACTICE ? 'errors.messages.profile_image_limit_reached' : 'errors.messages.profile_image_subscription_required'
    errors.add(:base, I18n.t(error_key, limit: limit))
  end

  def cache_file_url_for_deletion
    self.file_url_for_deletion = file_url_in_database.presence || file_url_was.presence || file_url
  end

  def delete_remote_asset
    url = file_url_for_deletion.presence || file_url
    return if url.blank?

    SimpleFileUpload::DeleteFile.new(file_url: url).call
  end

  def upload_limit_for_practice
    subscription = practice.subscription
    return MAX_PER_PRACTICE if subscription&.status == 'active'

    MAX_WITHOUT_SUBSCRIPTION
  end

  def delete_pending_upload
    return if @pending_upload_deleted
    return if file_url.blank?

    SimpleFileUpload::DeleteFile.new(file_url: file_url).call
  rescue StandardError => e
    Rails.logger.error("Failed to delete pending profile image upload: #{e.message}")
  ensure
    self.file_url = nil
    @pending_upload_deleted = true
  end
end
