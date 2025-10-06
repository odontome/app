# frozen_string_literal: true

class ProfileImage < ApplicationRecord
  MAX_PER_PRACTICE = 500

  belongs_to :practice, counter_cache: true
  belongs_to :imageable, polymorphic: true

  validates :file_url, presence: true
  validates :practice, presence: true
  validates :imageable, presence: true
  validate :enforce_practice_upload_limit, on: :create

  after_destroy_commit :delete_remote_asset

  private

  def enforce_practice_upload_limit
    return if practice.blank?

    current_count = practice.profile_images_count.to_i
    return unless current_count >= MAX_PER_PRACTICE

    errors.add(:base, I18n.t('errors.messages.profile_image_limit_reached', limit: MAX_PER_PRACTICE))
  end

  def delete_remote_asset
    SimpleFileUpload::DeleteFile.new(file_url: file_url).call
  end
end
