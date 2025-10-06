# frozen_string_literal: true

require 'test_helper'
require 'ostruct'

class ProfileImageTest < ActiveSupport::TestCase
  test 'sets practice automatically from imageable' do
    doctor = Doctor.create!(
      practice: practices(:complete),
      firstname: 'Auto',
      lastname: 'Practice',
      email: 'auto.practice@example.com'
    )

    doctor.profile_picture_url = 'https://cdn.simplefileupload.com/new-profile.jpg'
    doctor.save!

    assert_equal doctor.practice, doctor.profile_image.practice
    assert_equal 'https://cdn.simplefileupload.com/new-profile.jpg', doctor.profile_picture_url
  ensure
    if doctor&.persisted?
      SimpleFileUpload::DeleteFile.stub(:new, ->(**_kwargs) { OpenStruct.new(call: true) }) do
        doctor.destroy
      end
    end
  end

  test 'enforces per practice upload limit' do
    practice = practices(:trialing_practice)
    practice.update!(profile_images_count: ProfileImage::MAX_PER_PRACTICE)

    doctor = Doctor.create!(
      practice: practice,
      firstname: 'Limited',
      lastname: 'Doctor',
      email: 'limited.doctor@example.com'
    )

    image = ProfileImage.new(practice: practice, imageable: doctor, file_url: 'https://cdn.example.com/limited.jpg')

    assert_not image.valid?
    assert_includes image.errors[:base], I18n.t('errors.messages.profile_image_limit_reached', limit: ProfileImage::MAX_PER_PRACTICE)

    practice.update!(profile_images_count: ProfileImage::MAX_PER_PRACTICE - 1)

    assert_difference -> { practice.reload.profile_images_count } do
      doctor.update!(profile_picture_url: 'https://cdn.example.com/allowed.jpg')
    end
  ensure
    if doctor&.persisted?
      SimpleFileUpload::DeleteFile.stub(:new, ->(**_kwargs) { OpenStruct.new(call: true) }) do
        doctor.destroy
      end
    end
    practice.update!(profile_images_count: 0)
  end
end
