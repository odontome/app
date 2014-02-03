require "redis"

uri = URI.parse(ENV["REDISTOGO_URL"])
REDIS = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)

THROTTLE_TIME_WINDOW = 60 * 60
THROTTLE_MAX_REQUESTS = 50