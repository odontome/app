# frozen_string_literal: true

require 'test_helper'
require 'ostruct'
require 'securerandom'

class ProfileImageTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
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
      with_delete_file_stub do |_|
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
      with_delete_file_stub do |_|
        doctor.destroy
      end
    end
    practice.update!(profile_images_count: 0)
  end

  test 'destroying a patient removes profile image and remote asset' do
    practice = practices(:complete)
    patient = Patient.create!(
      practice: practice,
      firstname: 'Destroyable',
      lastname: 'Patient',
      date_of_birth: 25.years.ago.to_date,
      email: "cleanup-#{SecureRandom.hex(4)}@example.com"
    )

    patient.update!(profile_picture_url: 'https://cdn.simplefileupload.com/destroyable.jpg')
    image_id = patient.profile_image.id
    expected_url = patient.profile_image.file_url

    with_delete_file_stub do |calls|
      patient.destroy!
      assert_remote_delete_invoked(calls, expected_url)
    end

    assert_not Patient.exists?(patient.id)
    assert_not ProfileImage.exists?(image_id)
  ensure
    cleanup_patient_without_remote_delete(patient)
  end

  test 'clearing a profile picture removes stored image and remote asset' do
    practice = practices(:complete)
    patient = Patient.create!(
      practice: practice,
      firstname: 'Removable',
      lastname: 'Patient',
      date_of_birth: 30.years.ago.to_date,
      email: "remove-#{SecureRandom.hex(4)}@example.com"
    )

    patient.update!(profile_picture_url: 'https://cdn.simplefileupload.com/removable.jpg')
    image_id = patient.profile_image.id
    expected_url = patient.profile_image.file_url

    with_delete_file_stub do |calls|
      patient.update!(profile_picture_url: '')
      assert_remote_delete_invoked(calls, expected_url)
    end

    patient.reload
    assert_nil patient.profile_image
    assert_not ProfileImage.exists?(image_id)
  ensure
    cleanup_patient_without_remote_delete(patient)
  end

  test 'destroying a practice cascades remote profile image deletion' do
    practice = build_practice_with_admin

    patient = practice.patients.create!(
      firstname: 'Practice',
      lastname: 'Scoped',
      date_of_birth: 28.years.ago.to_date,
      email: "practice-#{SecureRandom.hex(4)}@example.com"
    )
    patient.update!(profile_picture_url: 'https://cdn.simplefileupload.com/practice.jpg')
    expected_url = patient.profile_image.file_url
    image_id = patient.profile_image.id

    with_delete_file_stub do |calls|
      practice.destroy!
      assert_remote_delete_invoked(calls, expected_url)
    end

    assert_not Practice.exists?(practice.id)
    assert_not Patient.exists?(patient.id)
    assert_not ProfileImage.exists?(image_id)
  end

  private

  def with_delete_file_stub
    calls = []
    klass = SimpleFileUpload::DeleteFile.singleton_class
    original_new = klass.instance_method(:new)

    klass.define_method(:new) do |file_url:, logger: Rails.logger|
      _ = logger
      entry = { url: file_url, called: false }
      calls << entry

      Object.new.tap do |obj|
        obj.define_singleton_method(:call) do
          entry[:called] = true
        end
      end
    end

    yield calls
  ensure
    klass.define_method(:new, original_new)
  end

  def assert_remote_delete_invoked(calls, url)
    entry = calls.find { |call| call[:url] == url }
    assert_not_nil entry, "Expected remote delete to be invoked for #{url}"
    assert entry[:called], "Expected remote delete for #{url} to call the API"
  end

  def cleanup_patient_without_remote_delete(patient)
    return unless patient&.persisted?

    with_delete_file_stub do |_|
      patient.destroy!
    end
  end

  def build_practice_with_admin
    Practice.create!(
      name: "Temp Practice #{SecureRandom.hex(4)}",
      timezone: 'Europe/London',
      locale: 'en',
      currency: 'usd',
      users_attributes: [
        {
          firstname: 'Temp',
          lastname: 'Admin',
          email: "temp-admin-#{SecureRandom.hex(4)}@example.com",
          roles: 'admin',
          password: 'password1',
          password_confirmation: 'password1'
        }
      ]
    )
  end
end
