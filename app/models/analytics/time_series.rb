# frozen_string_literal: true

module Analytics
  module TimeSeries
    module_function

    # Returns an array of formatted labels for each day in the range
    def labels_for(range)
      (range.begin.to_date..range.end.to_date).map { |date| date.strftime('%a %d') }
    end

    # Given a range and a hash keyed by Date => value, returns an array of values aligned per day in the range
    def normalize_daily(range, date_to_value)
      (range.begin.to_date..range.end.to_date).map { |date| (date_to_value[date] || 0) }
    end

    # Utility: returns a hash { Date => count } for a relation grouped by DATE(column)
    def count_by_day(relation, column)
      relation.group("DATE(#{column})").order("DATE(#{column}) ASC").count.transform_keys do |k|
        k.is_a?(Date) ? k : Date.parse(k.to_s)
      end
    end

    # Utility: returns a hash { Date => sum } for a relation grouped by DATE(column) and summed on field
    def sum_by_day(relation, column, field)
      relation.group("DATE(#{column})").order("DATE(#{column}) ASC").sum(field).transform_keys do |k|
        k.is_a?(Date) ? k : Date.parse(k.to_s)
      end
    end
  end
end
