# frozen_string_literal: true

module PatientsHelper
  def letter_options
    alphabet = [*'A'..'Z']
    patients = Patient.with_practice(current_user.practice_id).only_initials.map(&:firstname).map(&:upcase)

    alphabet.map do |letter|
      {
        value: letter,
        included?: patients.include?(letter)
      }
    end
  end

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

  def patients_segment_pills
    content_tag(:ul, class: 'nav nav-pills mb-3') do
      today_pill = content_tag(:li, class: 'nav-item') do
        link_to patients_url(segment: 'today'),
                class: "nav-link #{@segment == 'today' ? 'active' : ''}" do
          safe_join([t(:patients_segment_today), " (#{@today_count})"])
        end
      end

      all_pill = content_tag(:li, class: 'nav-item') do
        link_to t(:patients_segment_all),
                patients_url(segment: 'all'),
                class: "nav-link #{@segment == 'all' ? 'active' : ''}"
      end

      today_pill + all_pill
    end
  end

  def appointment_time_with_duration(starts_at, ends_at)
    time = starts_at.strftime('%l:%M %p').strip
    duration = ((ends_at - starts_at) / 60).round
    t(:appointment_time_duration, time: time, duration: duration)
  end

  def appointment_status_badge(status)
    case status
    when Appointment.status[:confirmed]
      label_tag t(:appointment_status_confirmed), :green
    when Appointment.status[:waiting_room]
      label_tag t(:appointment_status_waiting), :azure
    when Appointment.status[:cancelled]
      label_tag t(:appointment_status_cancelled), :red
    end
  end
end
