# frozen_string_literal: true

require 'test_helper'
require 'minitest/mock'

class ProfileImageableTest < ActiveSupport::TestCase
  setup do
    I18n.locale = :en
  end

  test 'accepts valid profile picture' do
    doctor = build_doctor
    attach_picture(doctor, size: 10_000)

    assert doctor.valid?
  end

  test 'rejects profile pictures larger than allowed limit' do
    doctor = build_doctor
    attach_picture(doctor, size: ProfileImageable::MAX_FILE_SIZE + 1)

    assert_not doctor.valid?
    expected_message = I18n.t(
      'errors.messages.profile_picture_too_large',
      limit: ActiveSupport::NumberHelper.number_to_human_size(ProfileImageable::MAX_FILE_SIZE)
    )
    assert_includes doctor.errors[:profile_picture], expected_message
    assert_not doctor.profile_picture.attached?
  end

  test 'rejects profile pictures with invalid content type' do
    doctor = build_doctor
    attach_picture(doctor, size: 10_000, content_type: 'application/pdf')

    assert_not doctor.valid?
    assert_includes doctor.errors[:profile_picture], I18n.t('errors.messages.profile_picture_invalid_type')
    assert_not doctor.profile_picture.attached?
  end

  test 'enforces practice limit without active subscription' do
    doctor = build_doctor(practice: practices(:complete))
    counter = Minitest::Mock.new
    counter.expect(:count, Practice::PROFILE_PICTURE_MAX_WITHOUT_SUBSCRIPTION)

    ProfilePictureCounter.stub(:new, ->(**_args) { counter }) do
      attach_picture(doctor, size: 10_000)

      assert_not doctor.valid?
      assert_includes doctor.errors[:profile_picture],
                      I18n.t('errors.messages.profile_image_subscription_required',
                             limit: Practice::PROFILE_PICTURE_MAX_WITHOUT_SUBSCRIPTION)
      assert_not doctor.profile_picture.attached?
    end

    assert_mock counter
  end

  test 'enforces practice limit for subscribed practice' do
    subscribed_practice = practices(:complete_another_language)
    doctor = build_doctor(practice: subscribed_practice)

    counter = Minitest::Mock.new
    counter.expect(:count, Practice::PROFILE_PICTURE_MAX_PER_PRACTICE)

    ProfilePictureCounter.stub(:new, ->(**_args) { counter }) do
      attach_picture(doctor, size: 10_000)

      assert_not doctor.valid?
      assert_includes doctor.errors[:profile_picture],
                      I18n.t('errors.messages.profile_image_limit_reached',
                             limit: Practice::PROFILE_PICTURE_MAX_PER_PRACTICE)
      assert_not doctor.profile_picture.attached?
    end

    assert_mock counter
  end

  private

  def build_doctor(practice: practices(:complete))
    Doctor.new(
      practice: practice,
      firstname: 'Test',
      lastname: 'Doctor',
      email: 'test-doctor@example.com'
    )
  end

  def attach_picture(record, size:, content_type: 'image/png')
    record.profile_picture.attach(
      io: StringIO.new('a' * size),
      filename: 'avatar.png',
      content_type: content_type
    )
  end
end
