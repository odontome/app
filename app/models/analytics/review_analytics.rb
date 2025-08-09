# frozen_string_literal: true

module Analytics
  class ReviewAnalytics
    def initialize(practice_id)
      @practice_id = practice_id
    end

    # Returns counts[] aligned to days in range
    def reviews_per_day(range)
      rel = Review
              .joins(appointment: { datebook: :practice })
              .where('practices.id = ?', @practice_id)
              .where('reviews.created_at >= ? AND reviews.created_at <= ?', range.begin, range.end)
      counts = Analytics::TimeSeries.count_by_day(rel, 'reviews.created_at')
      Analytics::TimeSeries.normalize_daily(range, counts)
    end

    # KPI total count for range
    def count(range)
      Review
        .joins(appointment: { datebook: :practice })
        .where('practices.id = ?', @practice_id)
        .where('reviews.created_at >= ? AND reviews.created_at <= ?', range.begin, range.end)
        .count
    end
  end
end
