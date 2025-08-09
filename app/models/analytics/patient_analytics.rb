# frozen_string_literal: true

module Analytics
  class PatientAnalytics
    def initialize(practice_id)
      @practice_id = practice_id
    end

    # Returns counts[] aligned to days in range
    def new_patients_per_day(range)
      rel = Patient
              .where(practice_id: @practice_id)
              .where('created_at >= ? AND created_at <= ?', range.begin, range.end)
      counts = Analytics::TimeSeries.count_by_day(rel, 'created_at')
      Analytics::TimeSeries.normalize_daily(range, counts)
    end

    # KPI total count for range
    def new_count(range)
      Patient
        .where(practice_id: @practice_id)
        .where('created_at >= ? AND created_at <= ?', range.begin, range.end)
        .count
    end
  end
end
