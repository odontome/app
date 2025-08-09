# frozen_string_literal: true

require 'test_helper'

class AnalyticsPatientTest < ActiveSupport::TestCase
  def setup
  @practice_id = practices(:complete).id
    @analytics = Analytics::PatientAnalytics.new(@practice_id)
  end

  test 'new_patients_per_day returns array aligned to range' do
    today = Time.zone.now.to_date
    range = today.beginning_of_week..today.end_of_week
    data = @analytics.new_patients_per_day(range)
    assert_equal data.length, (range.begin..range.end).count
  end

  test 'new_count returns integer for range' do
    today = Time.zone.now.to_date
    range = today.beginning_of_week..today.end_of_week
    total = @analytics.new_count(range)
    assert total.is_a?(Integer)
  end
end
