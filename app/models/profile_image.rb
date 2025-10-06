# frozen_string_literal: true

class ProfileImage < ApplicationRecord
  MAX_PER_PRACTICE = 500

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

    current_count = practice.profile_images_count.to_i
    return unless current_count >= MAX_PER_PRACTICE

    errors.add(:base, I18n.t('errors.messages.profile_image_limit_reached', limit: MAX_PER_PRACTICE))
  end

  def cache_file_url_for_deletion
    self.file_url_for_deletion = file_url_in_database.presence || file_url_was.presence || file_url
  end

  def delete_remote_asset
    url = file_url_for_deletion.presence || file_url
    return if url.blank?

    SimpleFileUpload::DeleteFile.new(file_url: url).call
  end
end
