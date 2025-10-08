# frozen_string_literal: true

module ProfileImageable
  extend ActiveSupport::Concern

  included do
    has_one_attached :profile_picture

    attr_accessor :remove_profile_picture

    validate :validate_profile_picture_size
    validate :validate_profile_picture_content_type
    validate :enforce_practice_profile_picture_limit

    before_save :purge_profile_picture_if_requested
  end

  def profile_picture_variant(width:, height:)
    return unless profile_picture.attached?

    return profile_picture unless profile_picture.variable?

    profile_picture.variant(resize_to_fill: [width, height])
  end

  private

  MAX_FILE_SIZE = 1.megabyte
  ALLOWED_CONTENT_TYPES = %w[image/png image/jpeg image/jpg].freeze

  def validate_profile_picture_size
    return unless profile_picture.attached?

    blob = profile_picture.blob
    return unless blob

    return if blob.byte_size <= MAX_FILE_SIZE

    human_limit = ActiveSupport::NumberHelper.number_to_human_size(MAX_FILE_SIZE)
    errors.add(:profile_picture, I18n.t('errors.messages.profile_picture_too_large', limit: human_limit))
    profile_picture.detach
  end

  def validate_profile_picture_content_type
    return unless profile_picture.attached?

    blob = profile_picture.blob
    return unless blob

    return if ALLOWED_CONTENT_TYPES.include?(blob.content_type)

    errors.add(:profile_picture, I18n.t('errors.messages.profile_picture_invalid_type'))
    profile_picture.detach
  end

  def enforce_practice_profile_picture_limit
    return unless should_check_profile_picture_limit?

    practice = practice_for_profile_picture
    return if practice.blank?

    limit = practice.profile_picture_upload_limit
    current_count = ProfilePictureCounter.new(practice: practice).count

    return if current_count < limit

    error_key = limit == Practice::PROFILE_PICTURE_MAX_PER_PRACTICE ? 'errors.messages.profile_image_limit_reached' : 'errors.messages.profile_image_subscription_required'
    errors.add(:profile_picture, I18n.t(error_key, limit: limit))
    profile_picture.detach
  end

  def should_check_profile_picture_limit?
    practice_for_profile_picture.present? && profile_picture_pending_attachment? && !profile_picture_already_attached?
  end

  def profile_picture_pending_attachment?
    profile_picture.attachment.present? && !profile_picture.attachment.persisted?
  end

  def profile_picture_already_attached?
    return false unless persisted?

    ActiveStorage::Attachment.exists?(record_type: self.class.name, record_id: id, name: 'profile_picture')
  end

  def practice_for_profile_picture
    return unless respond_to?(:practice)

    practice
  end

  def purge_profile_picture_if_requested
    return unless ActiveModel::Type::Boolean.new.cast(remove_profile_picture)

    profile_picture.purge_later if profile_picture.attached?
  end
end
