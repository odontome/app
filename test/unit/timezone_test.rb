# frozen_string_literal: true

require 'test_helper'

class TimeZoneTest < ActiveSupport::TestCase
  test 'balance attributes must not be empty' do
    timezones = ActiveSupport:TimeZone.all_where_hour_is 14
    assert_equal [], timezones
  end
end
