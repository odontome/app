# frozen_string_literal: true

require 'net/http'
require 'ipaddr'
require 'socket'
require 'timeout'

# Public OAuth clients identify themselves with an HTTPS metadata document.
class AgentOauthClient
  DOCUMENT_TIMEOUT = 5
  MAX_DOCUMENT_BYTES = 64 * 1024
  MAX_URL_BYTES = 2048
  CACHE_TTL = 1.hour.to_i
  LOOPBACK_HOSTS = %w[localhost 127.0.0.1 ::1].freeze
  SPECIAL_USE_RANGES = %w[
    0.0.0.0/8 10.0.0.0/8 100.64.0.0/10 127.0.0.0/8 169.254.0.0/16
    172.16.0.0/12 192.0.0.0/24 192.0.2.0/24 192.88.99.0/24
    192.168.0.0/16 198.18.0.0/15 198.51.100.0/24 203.0.113.0/24
    224.0.0.0/4 240.0.0.0/4 2001::/23 2001:db8::/32 2002::/16 3fff::/20
  ].map { |range| IPAddr.new(range) }.freeze
  GLOBAL_IPV6 = IPAddr.new('2000::/3')
  class InvalidDocument < StandardError; end

  attr_reader :client_id, :document

  def self.find(client_id)
    url = parse_uri(client_id)
    return unless url.is_a?(URI::HTTPS) && url.query.nil? && url.fragment.nil? && url.userinfo.nil?
    return if url.path.blank? || url.path == '/' || url.path.split('/').intersect?(%w[. ..])

    key = "agent_oauth_client/#{Digest::SHA256.hexdigest(client_id)}"
    document = Rails.cache.read(key)
    unless document
      result = download(url)
      return unless result

      document, ttl = result
      client = new(client_id, document)
      return unless client.valid?

      Rails.cache.write(key, document, expires_in: ttl) if ttl.positive?
      return client
    end
    client = new(client_id, document)
    client if client.valid?
  end

  def self.parse_uri(value)
    return unless value.is_a?(String) && value.bytesize <= MAX_URL_BYTES

    uri = URI.parse(value)
    uri if uri.is_a?(URI::HTTP) && uri.hostname.present?
  rescue URI::InvalidURIError
    nil
  end

  def self.public_address?(value)
    address = IPAddr.new(value).native
    return false if address.ipv6? && !GLOBAL_IPV6.include?(address)

    SPECIAL_USE_RANGES.none? { |range| range.include?(address) }
  rescue IPAddr::InvalidAddressError
    false
  end

  def self.download(url)
    # Include DNS, TLS and the entire body in the deadline, not just each read.
    Timeout.timeout(DOCUMENT_TIMEOUT) do
      addresses = Addrinfo.getaddrinfo(url.hostname, url.port, nil, :STREAM).map(&:ip_address).uniq
      raise InvalidDocument if addresses.empty? || !addresses.all? { |address| public_address?(address) }

      # Pin the vetted address, keep the hostname for SNI/certificate checks,
      # and disable ambient proxies so neither path can re-resolve the host.
      http = Net::HTTP.new(url.hostname, url.port, nil)
      http.ipaddr = addresses.first
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      http.verify_hostname = true
      http.open_timeout = http.read_timeout = http.write_timeout = DOCUMENT_TIMEOUT
      http.max_retries = 0
      http.start do |connection|
        request = Net::HTTP::Get.new(url.request_uri, 'Accept' => 'application/json', 'Accept-Encoding' => 'identity')
        connection.request(request) do |response|
          raise InvalidDocument unless response.is_a?(Net::HTTPOK)
          raise InvalidDocument unless response.content_type == 'application/json'
          raise InvalidDocument if response['Content-Length'].to_i > MAX_DOCUMENT_BYTES

          body = +''
          response.read_body do |chunk|
            raise InvalidDocument if body.bytesize + chunk.bytesize > MAX_DOCUMENT_BYTES

            body << chunk
          end
          return [JSON.parse(body), cache_lifetime(response)]
        end
      end
    end
  rescue InvalidDocument, SocketError, SystemCallError, IOError, Timeout::Error,
         OpenSSL::SSL::SSLError, Net::HTTPBadResponse, JSON::ParserError
    nil
  end

  def self.cache_lifetime(response)
    control = response['Cache-Control'].to_s.downcase
    return 0 if control.match?(/(?:\A|,)\s*(?:no-store|no-cache|private)(?:\s|=|,|\z)/)

    max_age = control[/(?:\A|,)\s*s-maxage="?(\d+)/, 1] || control[/(?:\A|,)\s*max-age="?(\d+)/, 1]
    lifetime = max_age ? max_age.to_i : CACHE_TTL
    [[lifetime - response['Age'].to_i, 0].max, CACHE_TTL].min
  end

  def initialize(client_id, document)
    @client_id = client_id
    @document = document
  end

  def valid?
    return false unless document.is_a?(Hash) && document['client_id'] == client_id
    return false unless document['client_name'].is_a?(String) && document['client_name'].present?
    return false unless document['redirect_uris'].is_a?(Array) && document['redirect_uris'].any?
    return false unless document['redirect_uris'].all? { |value| redirect_uri(value) }
    return false if document.key?('client_secret') || document.key?('client_secret_expires_at')

    method = document.fetch('token_endpoint_auth_method', 'none')
    methods = document.fetch('token_endpoint_auth_methods_supported', [method])
    return false unless %w[none private_key_jwt].include?(method) && string_list?(methods) && methods.include?('none')

    grants = document.fetch('grant_types', ['authorization_code'])
    responses = document.fetch('response_types', ['code'])
    string_list?(grants) && grants.include?('authorization_code') && string_list?(responses) && responses.include?('code')
  end

  def host
    URI.parse(client_id).hostname
  end

  def refresh_tokens?
    document.fetch('grant_types', []).include?('refresh_token')
  end

  def redirect_uri_allowed?(value)
    return false unless redirect_uri(value)

    document['redirect_uris'].any? do |registered|
      registered == value || (loopback_redirect?(value) && without_port(registered) == without_port(value))
    end
  end

  def loopback_redirect?(value)
    uri = self.class.parse_uri(value)
    uri && uri.scheme == 'http' && local_redirect?(value)
  end

  def local_redirect?(value)
    uri = self.class.parse_uri(value)
    uri && LOOPBACK_HOSTS.include?(uri.hostname)
  end

  private

  def string_list?(value)
    value.is_a?(Array) && value.all? { |item| item.is_a?(String) }
  end

  def redirect_uri(value)
    uri = self.class.parse_uri(value)
    return unless uri && uri.userinfo.nil? && uri.fragment.nil?
    return if URI.decode_www_form(uri.query.to_s).any? { |key,| %w[code error state iss].include?(key) }

    uri if uri.scheme == 'https' || loopback_redirect?(value)
  end

  def without_port(value)
    # Preserve every original byte except the loopback port, including query,
    # path, encoding and casing. URI serialization would normalize other bytes.
    value.sub(%r{\A([^:/]+://(?:\[[^\]]+\]|[^/?#:]+)):\d+(?=[/?]|\z)}, '\\1')
  end
end
