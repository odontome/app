# frozen_string_literal: true

require 'stringio'

class ProfilePictureNormalizer
  def initialize(record)
    @record = record
  end

  def call
    return unless record.profile_picture.attached?

    blob = record.profile_picture.blob
    return unless blob
    return unless record.profile_picture.variable?
    return if blob.metadata[ProfileImageable::PROFILE_PICTURE_RESIZED_METADATA_KEY]

    large_dimensions = ProfileImageable::PROFILE_PICTURE_VARIANT_DIMENSIONS[:large]
    processed_variant = record.profile_picture.variant(resize_to_fill: large_dimensions).processed
    resized_data = processed_variant.image.download

    new_metadata = blob.metadata.merge(ProfileImageable::PROFILE_PICTURE_RESIZED_METADATA_KEY => true)

    record.profile_picture.attach(
      io: StringIO.new(resized_data),
      filename: blob.filename,
      content_type: blob.content_type,
      metadata: new_metadata
    )

    blob.purge_later
    record.profile_picture.reload
  rescue StandardError => e
    handle_processing_failure(blob, e)
  end

  private

  attr_reader :record

  def handle_processing_failure(blob, error)
    if normalization_can_be_marked?(error)
      mark_blob_as_normalized(blob)
      Rails.logger.warn("Marked profile picture as normalized without processing for #{record.class.name}##{record.id}: #{error.class} - #{error.message}")
    else
      Rails.logger.error("Failed to normalize profile picture for #{record.class.name}##{record.id}: #{error.message}")
    end
  end

  def normalization_can_be_marked?(error)
    (defined?(ImageProcessing::Error) && error.is_a?(ImageProcessing::Error)) ||
      (defined?(MiniMagick::Error) && error.is_a?(MiniMagick::Error))
  end

  def mark_blob_as_normalized(blob)
    metadata = blob.metadata.merge(ProfileImageable::PROFILE_PICTURE_RESIZED_METADATA_KEY => true)
    blob.update!(metadata: metadata)
  rescue StandardError => e
    Rails.logger.error("Failed to mark profile picture metadata for #{record.class.name}##{record.id}: #{e.message}")
  end
end
