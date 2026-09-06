# frozen_string_literal: true

require 'test_helper'

class AnalyticsPatientTest < ActiveSupport::TestCase
  def setup
    @range = Time.utc(2024, 1, 1)..Time.utc(2024, 1, 7, 23, 59, 59)
    @analytics = Analytics::PatientAnalytics.new(practices(:complete).id)

    # Include both endpoints, with a record just outside each end of the week.
    [-1.second, 0, 12.hours, 7.days - 1.second, 7.days].each do |offset|
      create_patient(@range.begin + offset)
    end
    create_patient(@range.begin + 2.days, practice: practices(:trialing_practice))
  end

  test 'new_patients_per_day returns exact practice counts for the week' do
    assert_equal [2, 0, 0, 0, 0, 0, 1], @analytics.new_patients_per_day(@range)
  end

  test 'new_count includes only this practice and the requested week' do
    assert_equal 3, @analytics.new_count(@range)
  end

  private

  def create_patient(created_at, practice: practices(:complete))
    Patient.create!(practice: practice, firstname: 'Analytics', lastname: 'Patient',
                    date_of_birth: Date.new(1990, 1, 1), created_at: created_at)
  end
end
