# frozen_string_literal: true

simple_file_upload_config = begin
  secrets = Rails.application.config_for(:secrets)
  {
    public_key: secrets['simple_file_upload_key'],
    api_public_key: secrets['simple_file_upload_api_public_key'],
    api_secret_key: secrets['simple_file_upload_api_secret_key']
  }.compact
rescue StandardError
  {
    public_key: ENV['SIMPLE_FILE_UPLOAD_KEY'],
    api_public_key: ENV['SIMPLE_FILE_UPLOAD_API_PUBLIC_KEY'],
    api_secret_key: ENV['SIMPLE_FILE_UPLOAD_API_SECRET_KEY']
  }.compact
end

Rails.configuration.simple_file_upload = simple_file_upload_config.compact
