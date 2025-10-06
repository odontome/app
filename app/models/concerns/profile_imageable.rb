# frozen_string_literal: true

module ProfileImageable
  extend ActiveSupport::Concern

  included do
    has_one :profile_image, as: :imageable, dependent: :destroy, autosave: true

    before_validation :sync_profile_image_practice
  end

  def profile_picture_url
    profile_image&.file_url
  end

  def profile_picture_url=(value)
    if value.blank?
      if profile_image
        profile_image.file_url = nil
        profile_image.mark_for_destruction
      end
      return
    end

    image = profile_image || build_profile_image
    image.file_url = value
  end

  def profile_picture_resized(width:, height:)
    return if profile_picture_url.blank?

    "#{profile_picture_url}?w=#{width}&h=#{height}&fit=fill"
  end

  private

  def sync_profile_image_practice
    return unless profile_image
    return if profile_image.destroyed? || profile_image.marked_for_destruction?

    return unless respond_to?(:practice)

    profile_image.practice = practice if practice.present?
  end
end
