# frozen_string_literal: true

require 'test_helper'

class AnalyticsAppointmentTest < ActiveSupport::TestCase
  def setup
    @practice_id = practices(:complete).id
    @analytics = Analytics::AppointmentAnalytics.new(@practice_id)
  end

  test 'appointments_per_day returns labels and counts aligned to range' do
    today = Time.zone.now.to_date
    range = today.beginning_of_week..today.end_of_week
    labels, counts = @analytics.appointments_per_day(range)

    assert_equal labels.length, (range.begin..range.end).count
    assert_equal counts.length, labels.length
  end

  test 'count returns integer for range' do
    today = Time.zone.now.to_date
    range = today.beginning_of_week..today.end_of_week
    total = @analytics.count(range)

    assert total.is_a?(Integer)
  end
end
