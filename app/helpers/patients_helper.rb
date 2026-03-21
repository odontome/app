# frozen_string_literal: true

module PatientsHelper

  def patients_sort_link(column:, label_key:, letter:)
    label = t(label_key)
    return label unless letter.present?

    link_to(label,
            patients_url(letter: letter, sort: column, direction: next_patients_sort_direction(column)),
            class: patients_sort_link_class(column))
  end

  def next_patients_sort_direction(column)
    return 'asc' unless @sort_column == column

    @sort_direction == 'asc' ? 'desc' : 'asc'
  end

  def patients_sort_link_class(column)
    base_classes = 'text-decoration-underline'

    if @sort_column == column
      "#{base_classes} fw-semibold text-primary"
    else
      "#{base_classes} text-muted"
    end
  end


  def follow_up_overdue_label(last_visit_at)
    if last_visit_at.blank?
      content_tag(:span, t(:never), class: 'text-red fw-semibold')
    else
      months_ago = ((Time.current - last_visit_at) / 1.month).floor
      color = months_ago >= 9 ? 'text-red' : 'text-yellow'
      content_tag(:span, t(:follow_up_overdue, time: time_ago_in_words(last_visit_at)), class: "#{color} fw-semibold")
    end
  end

  def appointment_time_with_duration(starts_at, ends_at)
    time = starts_at.strftime('%l:%M %p').strip
    duration = ((ends_at - starts_at) / 60).round
    t(:appointment_time_duration, time: time, duration: duration)
  end
end
