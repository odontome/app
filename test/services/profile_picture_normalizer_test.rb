# frozen_string_literal: true

require 'test_helper'
require 'base64'

class ProfilePictureNormalizerTest < ActiveSupport::TestCase
  SAMPLE_IMAGE_BASE64 = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+rXbQAAAAASUVORK5CYII='

  setup do
    @patient = patients(:one)
    purge_attachment(@patient)
  end

  teardown do
    purge_attachment(@patient)
  end

  test 'replaces original blob with processed variant and marks metadata' do
    attach_sample_image(@patient)
    ProfilePictureNormalizer.new(@patient).call
    @patient.profile_picture.reload

    assert_equal 'image/png', @patient.profile_picture.blob.content_type
    key = ProfileImageable::PROFILE_PICTURE_RESIZED_METADATA_KEY
    assert @patient.profile_picture.blob.metadata[key]
    assert_not @patient.send(:profile_picture_requires_normalization?)
  end

  test 'does nothing when already normalized' do
    attach_sample_image(@patient)
    ProfilePictureNormalizer.new(@patient).call
    normalized_key = @patient.profile_picture.blob.key

    ProfilePictureNormalizer.new(@patient).call
    @patient.profile_picture.reload

    assert_equal normalized_key, @patient.profile_picture.blob.key
  end

  private

  def attach_sample_image(record)
    record.profile_picture.attach(
      io: StringIO.new(Base64.decode64(SAMPLE_IMAGE_BASE64)),
      filename: 'avatar.png',
      content_type: 'image/png'
    )
  end

  def purge_attachment(record)
    return unless record.profile_picture.attached?

    record.profile_picture.purge
  end
end
