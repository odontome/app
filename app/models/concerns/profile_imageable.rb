# frozen_string_literal: true

module ProfileImageable
  extend ActiveSupport::Concern

  included do
    has_one_attached :profile_picture

    validate :validate_profile_picture_size
    validate :validate_profile_picture_content_type
    validate :enforce_practice_profile_picture_limit

    before_save :purge_profile_picture_if_requested
    after_commit :ensure_profile_picture_normalized, if: -> { profile_picture_requires_normalization? }
  end

  attr_accessor :remove_profile_picture

  PROFILE_PICTURE_VARIANT_DIMENSIONS = {
    small: [128, 128],
    medium: [256, 256],
    large: [1024, 1024]
  }.freeze

  PROFILE_PICTURE_RESIZED_METADATA_KEY = 'profile_picture_resized'

  DEFAULT_PROFILE_PICTURE_VARIANT = :medium

  def profile_picture_variant(width: nil, height: nil, size: nil)
    return unless profile_picture.attached?

    return profile_picture unless profile_picture.variable?

    variant_key = resolve_profile_picture_variant(size: size, width: width, height: height)
    dimensions = PROFILE_PICTURE_VARIANT_DIMENSIONS.fetch(variant_key)

    profile_picture.variant(resize_to_fill: dimensions)
  end

  def profile_picture_small
    profile_picture_variant(size: :small)
  end

  def profile_picture_medium
    profile_picture_variant(size: :medium)
  end

  def profile_picture_large
    profile_picture_variant(size: :large)
  end

  private

  MAX_FILE_SIZE = 3.megabyte
  ALLOWED_CONTENT_TYPES = %w[image/png image/jpeg image/jpg].freeze

  def resolve_profile_picture_variant(size:, width:, height:)
    return normalize_profile_picture_variant(size) if size

    if width && height
      matched_key = PROFILE_PICTURE_VARIANT_DIMENSIONS.find { |_, dims| dims == [width, height] }&.first
      return matched_key if matched_key

      return closest_profile_picture_variant(width, height)
    end

    DEFAULT_PROFILE_PICTURE_VARIANT
  end

  def normalize_profile_picture_variant(size)
    key = size.to_sym
    PROFILE_PICTURE_VARIANT_DIMENSIONS.key?(key) ? key : DEFAULT_PROFILE_PICTURE_VARIANT
  end

  def closest_profile_picture_variant(width, height)
    PROFILE_PICTURE_VARIANT_DIMENSIONS.min_by do |_, dims|
      (dims[0] - width).abs + (dims[1] - height).abs
    end.first
  end

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

  def ensure_profile_picture_normalized
    return unless profile_picture_requires_normalization?

    ProfilePictureNormalizer.new(self).call
  end

  def profile_picture_requires_normalization?
    return false unless profile_picture.attached?

    blob = profile_picture.blob
    return false unless blob
    return false unless profile_picture.variable?

    !blob.metadata[PROFILE_PICTURE_RESIZED_METADATA_KEY]
  end
end
