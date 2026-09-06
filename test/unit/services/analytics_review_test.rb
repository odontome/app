# frozen_string_literal: true

require 'test_helper'

class AnalyticsReviewTest < ActiveSupport::TestCase
  def setup
    @range = Time.utc(2024, 1, 1)..Time.utc(2024, 1, 7, 23, 59, 59)
    @analytics = Analytics::ReviewAnalytics.new(practices(:complete).id)

    # Include both endpoints, with a record just outside each end of the week.
    [-1.second, 0, 12.hours, 7.days - 1.second, 7.days].each do |offset|
      create_review(@range.begin + offset)
    end

    foreign_practice = practices(:trialing_practice)
    foreign_doctor = Doctor.create!(practice: foreign_practice, firstname: 'Other', lastname: 'Doctor')
    foreign_datebook = Datebook.create!(practice: foreign_practice, name: 'Other calendar')
    create_review(@range.begin + 2.days, patient: patients(:three), doctor: foreign_doctor, datebook: foreign_datebook)
  end

  test 'reviews_per_day returns exact practice counts for the week' do
    assert_equal [2, 0, 0, 0, 0, 0, 1], @analytics.reviews_per_day(@range)
  end

  test 'count includes only this practice and the requested week' do
    assert_equal 3, @analytics.count(@range)
  end

  test 'returns zeros when no reviews in range' do
    empty_range = Time.utc(1900, 1, 1)..Time.utc(1900, 1, 7, 23, 59, 59)

    assert_equal [0, 0, 0, 0, 0, 0, 0], @analytics.reviews_per_day(empty_range)
    assert_equal 0, @analytics.count(empty_range)
  end

  private

  def create_review(created_at, patient: patients(:one),
                    doctor: doctors(:rebecca), datebook: datebooks(:playa_del_carmen))
    starts_at = Time.utc(2024, 1, 1, 12)
    appointment = Appointment.create!(patient: patient, doctor: doctor, datebook: datebook,
                                      starts_at: starts_at, ends_at: starts_at + 30.minutes)
    Review.create!(appointment: appointment, score: 4, comment: 'Analytics review', created_at: created_at)
  end
end
