# frozen_string_literal: true

require 'test_helper'

class AnalyticsBalanceTest < ActiveSupport::TestCase
  def setup
  @practice_id = practices(:complete).id
    @analytics = Analytics::BalanceAnalytics.new(@practice_id)
  end

  test 'revenue_per_day returns array aligned to range' do
    today = Time.zone.now.to_date
    range = today.beginning_of_week..today.end_of_week
    data = @analytics.revenue_per_day(range)
    assert_equal data.length, (range.begin..range.end).count
  end

  test 'sum returns numeric for range' do
    today = Time.zone.now.to_date
    range = today.beginning_of_week..today.end_of_week
    total = @analytics.sum(range)
    assert total.is_a?(Numeric)
  end
end
