# frozen_string_literal: true

require 'test_helper'
require 'ostruct'

class SimpleFileUploadsControllerTest < ActionController::TestCase
  setup do
    @controller.session['user'] = users(:founder)
  end

  test 'destroys remote asset when file url is present' do
    uploaded_file_url = 'https://cdn.simplefileupload.com/sample-image.jpg'
    deleted_urls = []

    @controller.define_singleton_method(:delete_remote_asset) do |file_url|
      deleted_urls << file_url
    end

    delete :destroy, params: { file_url: uploaded_file_url }, format: :json

    assert_response :no_content
    assert_equal [uploaded_file_url], deleted_urls
  end

  test 'clears doctor profile picture when file url matches current practice doctor' do
    uploaded_file_url = 'https://cdn.simplefileupload.com/existing-image.jpg'
    doctor = Doctor.create!(
      practice: practices(:complete),
      firstname: 'Matching',
      lastname: 'Doctor',
      email: 'matching.doctor@example.com',
      profile_picture_url: uploaded_file_url
    )
    profile_image_id = doctor.profile_image.id

    @controller.define_singleton_method(:delete_remote_asset) do |_file_url|
      # noop for test isolation
    end

    delete :destroy, params: { file_url: uploaded_file_url }, format: :json

    assert_response :no_content
    assert_nil doctor.reload.profile_picture_url
    assert_nil ProfileImage.find_by(id: profile_image_id)
  ensure
    if doctor&.persisted?
      SimpleFileUpload::DeleteFile.stub(:new, ->(**_kwargs) { OpenStruct.new(call: true) }) do
        doctor.destroy
      end
    end
  end

  test 'does not clear profile picture for doctors in other practices' do
    uploaded_file_url = 'https://cdn.simplefileupload.com/other-practice.jpg'
    other_doctor = Doctor.create!(
      practice: practices(:trialing_practice),
      firstname: 'Other',
      lastname: 'Practice',
      email: 'other.practice@example.com',
      profile_picture_url: uploaded_file_url
    )
    other_profile_image_id = other_doctor.profile_image.id

    @controller.define_singleton_method(:delete_remote_asset) do |_file_url|
      # noop for test isolation
    end

    delete :destroy, params: { file_url: uploaded_file_url }, format: :json

    assert_response :no_content
    assert_equal uploaded_file_url, other_doctor.reload.profile_picture_url
    assert ProfileImage.find_by(id: other_profile_image_id)
  ensure
    if other_doctor&.persisted?
      SimpleFileUpload::DeleteFile.stub(:new, ->(**_kwargs) { OpenStruct.new(call: true) }) do
        other_doctor.destroy
      end
    end
  end

  test 'returns bad_request when file url is missing' do
    deletion_calls = []

    @controller.define_singleton_method(:delete_remote_asset) do |file_url|
      deletion_calls << file_url
    end

    delete :destroy, params: { file_url: '' }, format: :json

    assert_response :bad_request
    assert_empty deletion_calls
  end

  test 'requires authenticated user' do
    @controller.session.delete('user')

    delete :destroy, params: { file_url: 'https://example.com/file.jpg' }, format: :json

    assert_redirected_to signin_path
  end
end
