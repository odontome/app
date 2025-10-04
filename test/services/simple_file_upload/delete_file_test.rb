# frozen_string_literal: true

require 'test_helper'
require 'minitest/mock'
require 'base64'

module SimpleFileUpload
  class DeleteFileTest < ActiveSupport::TestCase
    teardown do
      @original_config && Rails.configuration.simple_file_upload = @original_config
    end

    test 'returns early when file url is blank' do
      with_simple_file_upload_config(api_public_key: 'public', api_secret_key: 'secret') do
        Net::HTTP.stub(:new, ->(*_) { raise 'Net::HTTP should not be called' }) do
          result = DeleteFile.new(file_url: '').call
          assert_nil result
        end
      end
    end

    test 'returns early when credentials missing' do
      with_simple_file_upload_config(api_public_key: nil, api_secret_key: nil) do
        Net::HTTP.stub(:new, ->(*_) { raise 'Net::HTTP should not be called' }) do
          result = DeleteFile.new(file_url: 'https://uploads.simplefileupload.com/file').call
          assert_nil result
        end
      end
    end

    test 'sends delete request when configured' do
      with_simple_file_upload_config(api_public_key: '  pub-456  ', api_secret_key: "\nsec-789\n") do
        response = Net::HTTPSuccess.new('1.1', '200', 'OK')
        response.instance_variable_set(:@read, true)
        response.instance_variable_set(:@body, 'ok')

        fake_http = FakeHTTP.new(response)

        Net::HTTP.stub(:new, ->(*_) { fake_http }) do
          DeleteFile.new(file_url: 'https://cdn.simplefileupload.com/test-file').call
        end

        assert_equal 'DELETE', fake_http.last_request.method
        assert_equal '/api/v1/file?url=https%3A%2F%2Fcdn.simplefileupload.com%2Ftest-file',
                     fake_http.last_request.path
        expected_header = "Basic #{Base64.strict_encode64('pub-456:sec-789')}"
        assert_equal expected_header, fake_http.last_request['Authorization']
      end
    end

    test 'encodes file url when building request path' do
      with_simple_file_upload_config(api_public_key: 'pub', api_secret_key: 'secret') do
        response = Net::HTTPSuccess.new('1.1', '200', 'OK')
        response.instance_variable_set(:@read, true)
        response.instance_variable_set(:@body, 'ok')

        fake_http = FakeHTTP.new(response)

        Net::HTTP.stub(:new, ->(*_) { fake_http }) do
          file_url = 'https://cdn.simplefileupload.com/static/blobs/proxy/eyJfcmFpbHMiOiJqSDF+%3D'
          DeleteFile.new(file_url: file_url).call
        end

        assert_equal '/api/v1/file?url=https%3A%2F%2Fcdn.simplefileupload.com%2Fstatic%2Fblobs%2Fproxy%2FeyJfcmFpbHMiOiJqSDF%2B%253D',
                     fake_http.last_request.path
      end
    end

    private

    def with_simple_file_upload_config(**options)
      @original_config = Rails.configuration.simple_file_upload
      Rails.configuration.simple_file_upload = (@original_config || {}).to_h.merge(options)
      yield
    ensure
      Rails.configuration.simple_file_upload = @original_config
    end

    class FakeHTTP
      attr_accessor :use_ssl
      attr_reader :last_request

      def initialize(response)
        @response = response
        @use_ssl = false
      end

      def request(request)
        @last_request = request
        @response
      end
    end
  end
end
