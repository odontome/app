# frozen_string_literal: true

require 'test_helper'

class AgentOauthClientTest < ActiveSupport::TestCase
  include AgentOauthTestClients

  setup do
    @document = CLIENTS[:other].deep_dup
    @client_id = @document['client_id']
    @url = URI.parse(@client_id)
  end

  test 'accepts public metadata independently of provider and callback origin' do
    CLIENTS.each_value do |document|
      client = AgentOauthClient.new(document['client_id'], document)
      assert client.valid?, document['client_name']
      assert client.refresh_tokens?
      assert client.redirect_uri_allowed?(document['redirect_uris'].first)
      assert_equal URI.parse(document['client_id']).hostname, client.host
    end
  end

  test 'rejects malformed client identifiers before downloading' do
    invalid = [nil, [], {}, '', 'https://', 'https://example.com/a b', 'http://example.com/client.json',
      'https://example.com', 'https://example.com/', 'https://example.com/../client.json',
      'https://example.com/./client.json', 'https://user:pass@example.com/client.json',
      'https://example.com/client.json?q=1', 'https://example.com/client.json#fragment',
      'https://example.com/' + ('a' * AgentOauthClient::MAX_URL_BYTES)]
    AgentOauthClient.stub(:download, ->(*) { flunk 'invalid client URL reached network' }) do
      invalid.each { |value| assert_nil AgentOauthClient.find(value), value.inspect }
    end
  end

  test 'validates required fields and supported public authentication' do
    invalid = [nil, [], 'text', @document.except('client_id'), @document.merge('client_id' => 'https://other.example/id'),
      @document.except('client_name'), @document.merge('client_name' => []), @document.merge('client_name' => ' '),
      @document.merge('redirect_uris' => nil), @document.merge('redirect_uris' => []),
      @document.merge('redirect_uris' => ['https://unrelated.example/return', 5]),
      @document.merge('client_secret' => 'secret'), @document.merge('client_secret_expires_at' => 0),
      @document.merge('token_endpoint_auth_method' => 'client_secret_post'),
      @document.merge('token_endpoint_auth_method' => 'private_key_jwt'),
      @document.merge('token_endpoint_auth_methods_supported' => 'none'),
      @document.merge('token_endpoint_auth_methods_supported' => [nil, 'none']),
      @document.merge('grant_types' => 'authorization_code'), @document.merge('grant_types' => ['refresh_token']),
      @document.merge('response_types' => ['token']), @document.merge('response_types' => nil)]
    invalid.each { |document| assert_not AgentOauthClient.new(@client_id, document).valid?, document.inspect }
    client = AgentOauthClient.new(@client_id, @document.except('grant_types'))
    assert client.valid?
    assert_not client.refresh_tokens?
  end

  test 'redirects match exactly including host case explicit HTTPS port path and query' do
    callback = 'https://unrelated.example/return?value=a%20b&z=1'
    client = AgentOauthClient.new(@client_id, @document.merge('redirect_uris' => [callback]))
    assert client.redirect_uri_allowed?(callback)
    [nil, [], 'https://UNRELATED.example/return?value=a%20b&z=1', callback.sub('example/', 'example:443/'),
      callback.sub('/return', '/return/'), callback.sub('%20', '+'), callback + '&extra=1',
      callback + '#fragment', callback.sub('https://', 'https://user@'),
      'http://unrelated.example/return', 'custom-app:/callback', 'https://unrelated.example.evil/return',
      'https://unrelated.example/return?code=fixed', 'https://unrelated.example/return?error=fixed',
      'https://unrelated.example/return?state=fixed', 'https://unrelated.example/return?iss=fixed',
      'https://unrelated.example/return?bad=%ZZ'].each do |uri|
      assert_not client.redirect_uri_allowed?(uri), uri.inspect
    end
  end

  test 'HTTP loopback callbacks ignore only port and remain exact otherwise' do
    %w[localhost 127.0.0.1 [::1]].each do |host|
      callback = "http://#{host}:1234/callback?x=a%20b"
      client = AgentOauthClient.new(@client_id, @document.merge('redirect_uris' => [callback]))
      assert client.valid?
      assert client.loopback_redirect?(callback)
      assert client.local_redirect?(callback)
      assert client.redirect_uri_allowed?(callback.sub(':1234', ':9876'))
      assert client.redirect_uri_allowed?(callback.sub(':1234', ''))
      [callback.sub('/callback', '/other'), callback.sub('%20', '+'), callback + '#x',
        callback.sub('http:', 'https:'), callback.sub(host, '127.0.0.2')].each do |uri|
        assert_not client.redirect_uri_allowed?(uri), uri
      end
    end
    assert AgentOauthClient.new(@client_id, @document).local_redirect?('https://127.0.0.1/callback')
    assert_not AgentOauthClient.new(@client_id, @document).loopback_redirect?('https://127.0.0.1/callback')
    %w[http://localhost.evil/callback http://127.0.0.2/callback http://10.0.0.1/callback].each do |callback|
      assert_not AgentOauthClient.new(@client_id, @document.merge('redirect_uris' => [callback])).valid?
    end
  end

  test 'blocks special use IPv4 IPv6 mapped IPv4 and every non-global IPv6 address' do
    assert_not AgentOauthClient.public_address?('not-an-address')
    blocked = %w[0.0.0.0 10.1.2.3 100.64.0.1 127.0.0.1 169.254.169.254 172.16.1.1 192.0.0.1
      192.0.2.1 192.88.99.1 192.168.0.1 198.18.0.1 198.51.100.1 203.0.113.1 224.0.0.1 255.255.255.255
      :: ::1 fc00::1 fe80::1 ff02::1 ::ffff:127.0.0.1 ::ffff:169.254.169.254 64:ff9b::a00:1
      2001::1 2001:db8::1 2002:7f00:1:: 3fff::1]
    blocked.each { |address| assert_not AgentOauthClient.public_address?(address), address }
    %w[8.8.8.8 1.1.1.1 2606:4700:4700::1111 ::ffff:8.8.8.8].each do |address|
      assert AgentOauthClient.public_address?(address), address
    end
  end

  test 'rejects empty DNS answers and mixed public private DNS before HTTP' do
    [[], ['8.8.8.8', '127.0.0.1'], ['::ffff:10.0.0.1']].each do |addresses|
      dns = addresses.map { |address| Addrinfo.ip(address) }
      Addrinfo.stub(:getaddrinfo, dns) do
        Net::HTTP.stub(:new, ->(*) { flunk 'unsafe DNS reached HTTP' }) do
          assert_nil AgentOauthClient.download(@url)
        end
      end
    end
  end

  test 'pins vetted IP with original TLS hostname no proxy and bounded network settings' do
    response = http_response(body: @document.to_json, headers: { 'Cache-Control' => 'max-age=90' })
    with_http(response) do |http|
      assert_equal [@document, 90], AgentOauthClient.download(@url)
      assert_equal '8.8.8.8', http.ipaddr
      assert_equal @url.hostname, http.address
      assert http.use_ssl?
      assert_equal OpenSSL::SSL::VERIFY_PEER, http.verify_mode
      assert http.verify_hostname
      assert_equal 5, http.open_timeout
      assert_equal 5, http.read_timeout
      assert_equal 5, http.write_timeout
      assert_equal 0, http.max_retries
      assert_not http.proxy?
    end
  end

  test 'rejects redirects errors bad JSON wrong MIME and oversized streamed bodies' do
    responses = [http_response(status: '302', headers: { 'Location' => 'http://127.0.0.1/private' }),
      http_response(status: '500'), http_response(body: 'not json'),
      http_response(headers: { 'Content-Type' => 'text/html' }),
      http_response(headers: { 'Content-Length' => (AgentOauthClient::MAX_DOCUMENT_BYTES + 1).to_s }),
      http_response(chunks: ['a' * AgentOauthClient::MAX_DOCUMENT_BYTES, 'b'])]
    responses.each do |response|
      with_http(response) { assert_nil AgentOauthClient.download(@url) }
    end
  end

  test 'network and TLS errors fail closed and are not cached' do
    [SocketError, Errno::ECONNREFUSED, IOError, Timeout::Error, OpenSSL::SSL::SSLError, Net::HTTPBadResponse].each do |error|
      Addrinfo.stub(:getaddrinfo, ->(*) { raise error }) do
        assert_nil AgentOauthClient.find(@client_id), error.name
      end
    end
  end

  test 'total deadline includes DNS and a slowly arriving response body' do
    original_timeout = Timeout.method(:timeout)
    Timeout.stub(:timeout, ->(seconds, &block) { assert_equal 5, seconds; original_timeout.call(0.02, &block) }) do
      Addrinfo.stub(:getaddrinfo, ->(*) { sleep 1 }) do
        assert_nil AgentOauthClient.download(@url)
      end
      response = http_response
      response.define_singleton_method(:read_body) { |&block| loop { block.call(' '); sleep 0.005 } }
      with_http(response) { assert_nil AgentOauthClient.download(@url) }
    end
  end

  test 'cache lifetime obeys no-store no-cache private max-age s-maxage age and server cap' do
    { '' => 3600, 'max-age=90' => 90, 'public, max-age="90"' => 90,
      'max-age=9000' => 3600, 'max-age=0' => 0, 'no-store' => 0,
      'max-age=90, no-cache' => 0, 'private="field"' => 0,
      'max-age=90, s-maxage=10' => 10 }.each do |control, expected|
      assert_equal expected, AgentOauthClient.cache_lifetime('Cache-Control' => control)
    end
    assert_equal 60, AgentOauthClient.cache_lifetime('Cache-Control' => 'max-age=90', 'Age' => '30')
    assert_equal 0, AgentOauthClient.cache_lifetime('Cache-Control' => 'max-age=90', 'Age' => '100')
  end

  test 'only valid successful documents are cached and entries expire' do
    Rails.stub(:cache, ActiveSupport::Cache::MemoryStore.new) do
      calls = 0
      fetch = ->(*) { calls += 1; [@document, 60] }
      AgentOauthClient.stub(:download, fetch) do
        2.times { assert AgentOauthClient.find(@client_id) }
        assert_equal 1, calls
        travel 61.seconds do
          assert AgentOauthClient.find(@client_id)
          assert_equal 2, calls
        end
      end
    end
    [nil, [@document.merge('client_id' => 'wrong'), 60], [@document, 0]].each do |result|
      Rails.stub(:cache, ActiveSupport::Cache::MemoryStore.new) do
        calls = 0
        AgentOauthClient.stub(:download, ->(*) { calls += 1; result }) do
          2.times { AgentOauthClient.find(@client_id) }
          assert_equal 2, calls
        end
      end
    end
  end

  private

  def http_response(status: '200', body: '{}', headers: {}, chunks: nil)
    response = Net::HTTPResponse::CODE_TO_OBJ.fetch(status).new('1.1', status, 'test')
    { 'Content-Type' => 'application/json' }.merge(headers).each { |key, value| response[key] = value }
    response.define_singleton_method(:read_body) { |&block| (chunks || [body]).each(&block) }
    response
  end

  def with_http(response)
    http = Net::HTTP.new(@url.hostname, @url.port, nil)
    constructor = lambda do |host, port, proxy|
      assert_equal @url.hostname, host
      assert_equal 443, port
      assert_nil proxy
      http
    end
    request = lambda do |req, &block|
      assert_equal @url.request_uri, req.path
      assert_equal 'application/json', req['Accept']
      assert_equal 'identity', req['Accept-Encoding']
      block.call(response)
    end
    Addrinfo.stub(:getaddrinfo, [Addrinfo.ip('8.8.8.8')]) do
      Net::HTTP.stub(:new, constructor) do
        http.stub(:start, ->(&block) { block.call(http) }) do
          http.stub(:request, request) { yield http }
        end
      end
    end
  end
end
