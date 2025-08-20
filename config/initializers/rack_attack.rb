# frozen_string_literal: true

class Rack::Attack
  ### Throttle Spammy Clients ###

  # Throttle all requests by IP (60rpm)
  #
  # Key: "rack::attack:#{Time.now.to_i/:period}:req/ip:#{req.ip}"
  throttle('req/ip', limit: 300, period: 5.minutes) do |req|
    req.ip unless req.path.start_with?('/assets')
  end

  # Throttle POST requests to /user_session by IP address
  #
  # Key: "rack::attack:#{Time.now.to_i/:period}:logins/ip:#{req.ip}"
  throttle('logins/ip', limit: 5, period: 20.seconds) do |req|
    req.ip if req.path == '/user_session' && req.post?
  end

  # Throttle POST requests to /user_session by email param
  #
  # Key: "rack::attack:#{Time.now.to_i/:period}:logins/email:#{normalized_email}"
  #
  # Note: This creates a problem where a malicious user could intentionally
  # throttle logins for another user and force their login requests to be
  # denied, but that's not very common and shouldn't happen to you. (Knock
  # on wood!)
  throttle('logins/email', limit: 5, period: 20.seconds) do |req|
    if req.path == '/user_session' && req.post?
      # Normalize the email, using the same logic as your authentication process, to
      # protect against rate limit bypasses. Return the normalized email if present, nil otherwise.
      req.params['signin']['email'].to_s.downcase.gsub(/\s+/, '').presence
    end
  end
end

# Block suspicious requests for sign ups.
Rack::Attack.blocklist('block suspicious sign up requests') do |req|
  if req.path == '/practice' && req.post?
    practice_name = req.params['practice']['name']
    # There have been multiple instances of spam practices with only a single word in their names and
    # a vast number of uppercase and lowercase characters.
    practice_name.split.count == 1 && practice_name.scan(/[A-Z]/).count > 2
  end
end

# Block Russian IP ranges to prevent spam signups
Rack::Attack.blocklist('block russian spam signups') do |req|
  if req.path == '/practice' && req.post?
    begin
      ip = IPAddr.new(req.ip)
      
      # Known Russian IP ranges commonly used for spam
      russian_ranges = [
        '5.8.0.0/13',        # Russia Telecom
        '5.16.0.0/12',       # Russia Telecom
        '5.34.0.0/15',       # Russia Telecom
        '5.39.0.0/16',       # Russia Telecom
        '5.44.0.0/14',       # Russia Telecom
        '5.53.0.0/16',       # Russia Telecom
        '31.7.192.0/18',     # Russia Telecom
        '31.131.0.0/16',     # Russia Telecom
        '46.17.0.0/16',      # Russia Telecom
        '46.29.0.0/16',      # Russia Telecom
        '46.32.0.0/11',      # Russia Telecom
        '46.61.0.0/16',      # Russia Telecom
        '77.37.0.0/16',      # Russia Telecom
        '77.88.0.0/16',      # Yandex
        '87.226.0.0/16',     # Russia Telecom
        '87.229.0.0/16',     # Russia Telecom
        '87.236.0.0/14',     # Russia Telecom
        '87.240.0.0/12',     # Russia Telecom
        '91.195.0.0/16',     # Russia Telecom
        '91.207.0.0/16',     # Russia Telecom
        '91.213.0.0/16',     # Russia Telecom
        '93.100.0.0/15',     # Russia Telecom
        '93.115.0.0/16',     # Russia Telecom
        '93.158.0.0/15',     # Russia Telecom
        '93.175.0.0/16',     # Russia Telecom
        '95.24.0.0/13',      # Russia Telecom
        '95.32.0.0/12',      # Russia Telecom
        '95.48.0.0/11',      # Russia Telecom
        '176.8.0.0/13',      # Russia Telecom
        '176.16.0.0/12',     # Russia Telecom
        '176.32.0.0/11',     # Russia Telecom
        '176.64.0.0/10',     # Russia Telecom
        '178.16.0.0/12',     # Russia Telecom
        '178.32.0.0/11',     # Russia Telecom
        '178.64.0.0/10',     # Russia Telecom
        '185.4.0.0/14',      # Russia Telecom
        '185.8.0.0/13',      # Russia Telecom
        '188.0.0.0/10',      # Russia Telecom
        '188.64.0.0/11',     # Russia Telecom
        '188.96.0.0/11',     # Russia Telecom
        '188.128.0.0/9',     # Russia Telecom
        '193.106.0.0/16',    # Russia Telecom
        '193.107.0.0/16',    # Russia Telecom
        '194.85.0.0/16',     # Russia Telecom
        '213.138.0.0/15',    # Russia Telecom
        '213.141.0.0/16',    # Russia Telecom
        '217.12.0.0/14',     # Russia Telecom
        '217.16.0.0/12'      # Russia Telecom
      ]
      
      russian_ranges.any? { |range| IPAddr.new(range).include?(ip) }
    rescue IPAddr::InvalidAddressError
      false
    end
  end
end

Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new # defaults to Rails.cache
