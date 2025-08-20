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

Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new # defaults to Rails.cache
