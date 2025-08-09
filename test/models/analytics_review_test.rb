# frozen_string_literal: true

require 'test_helper'

class AnalyticsReviewTest < ActiveSupport::TestCase
  def setup
  @practice_id = practices(:complete).id
    @analytics = Analytics::ReviewAnalytics.new(@practice_id)
  end

  test 'reviews_per_day returns array aligned to range' do
    today = Time.zone.now.to_date
    range = today.beginning_of_week..today.end_of_week
    data = @analytics.reviews_per_day(range)
    assert_equal data.length, (range.begin..range.end).count
  end

  test 'count returns integer for range' do
    today = Time.zone.now.to_date
    range = today.beginning_of_week..today.end_of_week
    total = @analytics.count(range)
    assert total.is_a?(Integer)
  end

  test 'returns zeros when no reviews in range' do
    far_past = Date.new(1900, 1, 1)
    range = far_past.beginning_of_week..far_past.end_of_week
    data = @analytics.reviews_per_day(range)
    assert_equal (range.begin..range.end).count, data.length
    assert_equal Array.new(data.length, 0), data
    assert_equal 0, @analytics.count(range)
  end
end
