# frozen_string_literal: true

require 'test_helper'

class RackAttackTest < ActionDispatch::IntegrationTest
  def setup
    # Reset Rack::Attack cache before each test
    Rack::Attack.cache.store.clear if Rack::Attack.cache.store.respond_to?(:clear)
    Rack::Attack.reset!
  end

  def teardown
    # Clean up after each test
    Rack::Attack.cache.store.clear if Rack::Attack.cache.store.respond_to?(:clear)
    Rack::Attack.reset!
  end

  test 'should throttle requests by IP address' do
    # First 299 requests should be allowed (limit is 300 per 5 minutes)
    299.times do |i|
      get '/signin', headers: { 'REMOTE_ADDR' => '192.168.1.100' }
      assert_response :success, "Request #{i + 1} should be successful"
    end

    # 300th request should still be allowed
    get '/signin', headers: { 'REMOTE_ADDR' => '192.168.1.100' }
    assert_response :success, '300th request should be successful'

    # 301st request should be throttled
    get '/signin', headers: { 'REMOTE_ADDR' => '192.168.1.100' }
    assert_response 429, '301st request should be throttled with 429 status'
  end

  test 'should throttle login attempts by IP address' do
    ip_address = '192.168.1.101'

    # First 4 login attempts should be allowed
    4.times do |i|
      post '/user_session', params: { signin: { email: 'test@example.com', password: 'wrong' } },
                            headers: { 'REMOTE_ADDR' => ip_address }
      assert_response :success, "Login attempt #{i + 1} should be successful"
    end

    # 5th login attempt should still be allowed
    post '/user_session', params: { signin: { email: 'test@example.com', password: 'wrong' } },
                          headers: { 'REMOTE_ADDR' => ip_address }
    assert_response :success, '5th login attempt should be successful'

    # 6th login attempt should be throttled
    post '/user_session', params: { signin: { email: 'test@example.com', password: 'wrong' } },
                          headers: { 'REMOTE_ADDR' => ip_address }
    assert_response 429, '6th login attempt should be throttled'
  end

  test 'should throttle login attempts by email' do
    email = 'throttle.test@example.com'

    # First 4 login attempts should be allowed
    4.times do |i|
      post '/user_session', params: { signin: { email: email, password: 'wrong' } },
                            headers: { 'REMOTE_ADDR' => "192.168.1.#{100 + i}" } # Different IPs
      assert_response :success, "Email login attempt #{i + 1}: #{response.status}"
    end

    # 5th login attempt should still be allowed
    post '/user_session', params: { signin: { email: email, password: 'wrong' } },
                          headers: { 'REMOTE_ADDR' => '192.168.1.200' }
    assert_response :success, "5th email login attempt: #{response.status}"

    # 6th login attempt should be throttled
    post '/user_session', params: { signin: { email: email, password: 'wrong' } },
                          headers: { 'REMOTE_ADDR' => '192.168.1.201' }
    assert_response 429, '6th email login attempt should be throttled'
  end

  test 'should block suspicious practice sign up requests' do
    # Practice name with single word and multiple uppercase characters should be blocked
    suspicious_name = 'SpAmPrAcTiCe'

    post '/practice', params: { practice: { name: suspicious_name } },
                      headers: { 'REMOTE_ADDR' => '192.168.1.102' }

    assert_response 403, 'Suspicious practice sign up should be blocked with 403 status'
  end

  test 'should block russian ip practice sign up requests' do
    # Test with various Russian IP ranges
    russian_ips = [
      '5.8.1.1',        # Russia Telecom range
      '77.88.55.55',    # Yandex IP
      '87.240.1.1',     # Russia Telecom range
      '188.1.1.1',      # Russia Telecom range
      '176.16.1.1',     # Russia Telecom range
      '93.100.1.1'      # Russia Telecom range
    ]

    russian_ips.each do |ip|
      post '/practice', params: { practice: { name: 'Test Practice' } },
                        headers: { 'REMOTE_ADDR' => ip }

      assert_response 403, "Russian IP #{ip} should be blocked from signing up"
    end
  end

  test 'should allow legitimate practice sign up requests' do
    # Practice name with multiple words should be allowed
    legitimate_name = 'Dr Smith Dental Practice'

    post '/practice', params: { practice: { name: legitimate_name } },
                      headers: { 'REMOTE_ADDR' => '192.168.1.103' }

    # Should not be blocked by Rack::Attack (actual response depends on your controller logic)
    assert_not_equal 403, response.status, 'Legitimate practice sign up should not be blocked'
  end

  test 'should allow legitimate non-russian ip practice sign up requests' do
    # Test with legitimate non-Russian IPs
    legitimate_ips = [
      '8.8.8.8',        # Google DNS (US)
      '1.1.1.1',        # Cloudflare DNS (US)
      '192.168.1.1',    # Private IP
      '10.0.0.1',       # Private IP
      '134.195.196.26', # US IP
      '82.165.190.32'   # EU IP
    ]

    legitimate_ips.each do |ip|
      post '/practice', params: { practice: { name: 'Dr Smith Dental Practice' } },
                        headers: { 'REMOTE_ADDR' => ip }

      assert_not_equal 403, response.status, "Legitimate IP #{ip} should not be blocked"
    end
  end

  test 'should handle invalid ip addresses gracefully' do
    # Test with malformed IP addresses - should not block but also not crash
    invalid_ips = [
      'invalid.ip',
      '999.999.999.999',
      '256.256.256.256',
      '',
      'localhost'
    ]

    invalid_ips.each do |ip|
      post '/practice', params: { practice: { name: 'Dr Smith Dental Practice' } },
                        headers: { 'REMOTE_ADDR' => ip }

      # Should not block invalid IPs (graceful degradation)
      assert_not_equal 403, response.status, "Invalid IP #{ip} should not cause blocking to fail"
    end
  end

  test 'should only block russian ips for practice signup, not other routes' do
    # Russian IP should only be blocked for practice signups, not other routes
    russian_ip = '77.88.55.55' # Yandex IP

    # Test login route - should not be blocked
    post '/user_session', params: { signin: { email: 'test@example.com', password: 'wrong' } },
                          headers: { 'REMOTE_ADDR' => russian_ip }
    assert_not_equal 403, response.status, 'Russian IP should not be blocked for login attempts'

    # Test other routes - should not be blocked
    get '/signin', headers: { 'REMOTE_ADDR' => russian_ip }
    assert_not_equal 403, response.status, 'Russian IP should not be blocked for other routes'

    # Test practice signup - should be blocked
    post '/practice', params: { practice: { name: 'Test Practice' } },
                      headers: { 'REMOTE_ADDR' => russian_ip }
    assert_response 403, 'Russian IP should be blocked for practice signup'
  end

  test 'should not throttle asset requests' do
    # Asset requests should be excluded from throttling
    301.times do
      get '/assets/application.css', headers: { 'REMOTE_ADDR' => '192.168.1.104' }
      # Don't assert success as asset might not exist in test, just ensure not throttled
      assert_not_equal 429, response.status, 'Asset requests should not be throttled'
    end
  end

  test 'different IPs should have separate throttle limits' do
    # Each IP should have its own throttle counter
    ip1 = '192.168.1.105'
    ip2 = '192.168.1.106'

    # Max out requests for IP1
    300.times do
      get '/signin', headers: { 'REMOTE_ADDR' => ip1 }
    end

    # IP1 should be throttled
    get '/signin', headers: { 'REMOTE_ADDR' => ip1 }
    assert_response 429, 'IP1 should be throttled'

    # IP2 should still be allowed
    get '/signin', headers: { 'REMOTE_ADDR' => ip2 }
    assert_response :success, 'IP2 should not be throttled'
  end

  test 'blocks signups from Russian timezones' do
    [
      'Europe/Moscow',
      'Europe/Samara',
      'Europe/Astrakhan',
      'Europe/Volgograd',
      'Europe/Saratov',
      'Europe/Ulyanovsk',
      'Europe/Kaliningrad'
    ].each do |tz|
      post '/practice', params: { practice: { name: 'Test Clinic', timezone: tz } }
      assert_response :forbidden, "Expected timezone #{tz} to be blocked"
    end
  end

  test 'allows signup from non-Russian timezone' do
    post '/practice', params: { practice: { name: 'Test Clinic', timezone: 'America/New_York' } }
    refute_equal 403, response.status, 'Non-Russian timezone should not be blocked'
  end
end
