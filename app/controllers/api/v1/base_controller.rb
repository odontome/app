class Api::V1::BaseController < ActionController::Base
  before_action :authenticate_user!, :throttle
  before_action :authorize_admin!, only: [:destroy]

  respond_to :json

  private

  def authenticate_user!
    authenticate_or_request_with_http_token do |token, _options|
      @current_user = User.find_by_authentication_token(token)

      if @current_user && !@current_user.authentication_token.nil?
        # FIXME: use JWT?
        # @current_user = UserSession.create(@current_user)
      else
        render json: { error: 'Token is invalid.' }, status: 401
      end
    end
  end

  def authorize_admin!
    authenticate_user!
    unless @current_user.user.roles.include?('admin')
      render json: { error: 'Sorry, you need to be an administrator of your practice to do that.' },
             status: 403
    end
  end

  def throttle
    client_ip = request.env['REMOTE_ADDR']
    key = "count:#{client_ip}"
    count = REDIS.get(key)

    unless count
      REDIS.set(key, 0)
      REDIS.expire(key, THROTTLE_TIME_WINDOW)
      return true
    end

    inject_rate_limit_headers key, count

    if count.to_i >= THROTTLE_MAX_REQUESTS
      render json: { message: 'You have fired too many requests. Please wait for some time.' }, status: 429
      return
    end
    REDIS.incr(key)
    true
  end

  def inject_rate_limit_headers(key, count)
    ttl = REDIS.ttl(key)
    time = Time.now.to_i
    time_till_reset = (time + ttl.to_i).to_s

    # inject these custom headers
    response.headers['X-Rate-Limit-Limit'] = THROTTLE_MAX_REQUESTS.to_s
    response.headers['X-Rate-Limit-Remaining'] = (THROTTLE_MAX_REQUESTS - count.to_i).to_s
    response.headers['X-Rate-Limit-Reset'] = time_till_reset
  end
end
