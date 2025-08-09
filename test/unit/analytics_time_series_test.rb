# frozen_string_literal: true

require 'test_helper'

class AnalyticsTimeSeriesTest < ActiveSupport::TestCase
  test 'labels_for returns one label per day formatted as `Mon dd`' do
    range = Date.new(2020, 1, 1).beginning_of_day..Date.new(2020, 1, 3).end_of_day
    labels = Analytics::TimeSeries.labels_for(range)
    assert_equal 3, labels.length
    assert labels.first.match?(/\A\w{3} \d{2}\z/)
  end

  test 'normalize_daily fills missing days with zeros and aligns values' do
    range = Date.new(2020, 1, 1).beginning_of_day..Date.new(2020, 1, 3).end_of_day
    data = {
      Date.new(2020, 1, 1) => 2,
      Date.new(2020, 1, 3) => 5
    }
    series = Analytics::TimeSeries.normalize_daily(range, data)
    assert_equal [2, 0, 5], series
  end

  test 'count_by_day returns counts keyed by Date' do
    # create three patients across two days
    practice = practices(:complete)
    d1 = Time.zone.local(2020, 2, 1, 10, 0, 0)
    d2 = Time.zone.local(2020, 2, 2, 9, 0, 0)

    p1 = Patient.create!(practice_id: practice.id, firstname: 'A', lastname: 'B', date_of_birth: '1990-01-01', created_at: d1)
    p2 = Patient.create!(practice_id: practice.id, firstname: 'C', lastname: 'D', date_of_birth: '1990-01-01', created_at: d1 + 1.hour)
    p3 = Patient.create!(practice_id: practice.id, firstname: 'E', lastname: 'F', date_of_birth: '1990-01-01', created_at: d2)

    rel = Patient.where(id: [p1.id, p2.id, p3.id])
    counts = Analytics::TimeSeries.count_by_day(rel, 'created_at')

    assert_equal 2, counts[Date.new(2020, 2, 1)]
    assert_equal 1, counts[Date.new(2020, 2, 2)]
  end

  test 'sum_by_day returns sums keyed by Date' do
    practice = practices(:complete)
    patient = Patient.create!(practice_id: practice.id, firstname: 'G', lastname: 'H', date_of_birth: '1990-01-01')

    d1 = Time.zone.local(2020, 3, 5, 11, 0, 0)
    d2 = Time.zone.local(2020, 3, 6, 12, 0, 0)

    b1 = Balance.create!(patient_id: patient.id, amount: 10.0, notes: '', created_at: d1)
    b2 = Balance.create!(patient_id: patient.id, amount: -5.0, notes: '', created_at: d1 + 2.hours)
    b3 = Balance.create!(patient_id: patient.id, amount: 7.0, notes: '', created_at: d2)

    rel = Balance.where(id: [b1.id, b2.id, b3.id])
    sums = Analytics::TimeSeries.sum_by_day(rel, 'balances.created_at', :amount)

    assert_equal 5.0, sums[Date.new(2020, 3, 5)]
    assert_equal 7.0, sums[Date.new(2020, 3, 6)]
  end
end
