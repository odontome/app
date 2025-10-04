# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'base64'

module SimpleFileUpload
  class DeleteFile
    API_ENDPOINT = URI.parse('https://app.simplefileupload.com/api/v1/file')

    def initialize(file_url:, logger: Rails.logger)
      @file_url = file_url
      @logger = logger
      @api_public_key, @api_secret_key = fetch_api_credentials
    end

    def call
      return if file_url.blank?
      return unless credentials_present?

      response = perform_request

      return if response.is_a?(Net::HTTPSuccess) || response&.code.to_i == 404

      logger.warn(
        "[SimpleFileUpload::DeleteFile] Failed to delete asset: status=#{response.code}, body=#{response.body}"
      )
    rescue StandardError => e
      logger.error("[SimpleFileUpload::DeleteFile] Error deleting asset: #{e.class}: #{e.message}")
    end

    private

    attr_reader :file_url, :logger, :api_public_key, :api_secret_key

    def fetch_api_credentials
      config = Rails.configuration.simple_file_upload || {}
      public_key = config[:api_public_key].to_s.strip.presence
      secret_key = config[:api_secret_key].to_s.strip.presence

      [public_key, secret_key]
    end

    def credentials_present?
      api_public_key.present? && api_secret_key.present?
    end

    def perform_request
      uri = API_ENDPOINT
      request_path = format('%<path>s?url=%<file_url>s', path: uri.path, file_url: file_url)

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      request = Net::HTTP::Delete.new(request_path)
      request['Authorization'] = build_authorization_header

      http.request(request)
    end

    def build_authorization_header
      credentials = format('%s:%s', api_public_key, api_secret_key)
      encoded_credentials = Base64.strict_encode64(credentials)
      format('Basic %s', encoded_credentials)
    end
  end
end
