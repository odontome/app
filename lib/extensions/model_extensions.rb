# frozen_string_literal: true

module ActiveRecord
  class Base
  end
end

module ActiveSupport
  class TimeZone
    def all_where_hour_is(hour)
      time = Time.now
      timezones = ActiveSupport::TimeZone.all
  
      timezones.select do |z|
        t = time.in_time_zone(z)
        t.hour == hour
      end.map(&:name)
    end
  end
end
