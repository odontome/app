# frozen_string_literal: true

module DatebooksHelper
  def hours_range(starts_at, ends_at)
    # turn the integers into a date
    starts_at = DateTime.now.utc.beginning_of_day + starts_at.to_i.hours
    ends_at = DateTime.now.utc.beginning_of_day + ends_at.to_i.hours

    # format the date to show only the hours
    starts_at = starts_at.strftime('%H:%M')
    ends_at = ends_at.strftime('%H:%M')

    "#{starts_at} - #{ends_at}"
  end
end
