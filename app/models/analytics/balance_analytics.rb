# frozen_string_literal: true

module Analytics
  class BalanceAnalytics
    def initialize(practice_id)
      @practice_id = practice_id
    end

    # Returns amounts[] aligned to days in range
    def revenue_per_day(range)
      rel = Balance
              .joins('LEFT OUTER JOIN patients ON balances.patient_id = patients.id')
              .where('patients.practice_id = ?', @practice_id)
              .where('balances.created_at >= ? AND balances.created_at <= ?', range.begin, range.end)
      sums = Analytics::TimeSeries.sum_by_day(rel, 'balances.created_at', :amount)
      Analytics::TimeSeries.normalize_daily(range, sums)
    end

    # KPI total sum for range
    def sum(range)
      Balance
        .joins('LEFT OUTER JOIN patients ON balances.patient_id = patients.id')
        .where('patients.practice_id = ?', @practice_id)
        .where('balances.created_at >= ? AND balances.created_at <= ?', range.begin, range.end)
        .sum(:amount)
    end
  end
end
