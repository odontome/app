# frozen_string_literal: true

module PatientsHelper
  def letter_options
    alphabet = [*'A'..'Z']
    present_initials = Patient.with_practice(current_user.practice_id)
                              .where.not(firstname_initial: nil)
                              .reorder('')
                              .distinct
                              .pluck(:firstname_initial)
                              .map(&:upcase)

    alphabet.map do |letter|
      {
        value: letter,
        included?: present_initials.include?(letter)
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
    return PatientsController::SORT_ASC unless @sort_column == column

    @sort_direction == PatientsController::SORT_ASC ? PatientsController::SORT_DESC : PatientsController::SORT_ASC
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

      follow_up_pill = content_tag(:li, class: 'nav-item') do
        link_to patients_url(segment: 'needs_follow_up'),
                class: "nav-link #{@segment == 'needs_follow_up' ? 'active' : ''}" do
          safe_join([t(:patients_segment_needs_follow_up), " (#{@follow_up_count})"])
        end
      end

      birthday_pill = content_tag(:li, class: 'nav-item') do
        link_to patients_url(segment: 'birthdays'),
                class: "nav-link #{@segment == 'birthdays' ? 'active' : ''}" do
          safe_join([t(:patients_segment_birthdays), " (#{@birthday_count})"])
        end
      end

      all_pill = content_tag(:li, class: 'nav-item') do
        link_to t(:patients_segment_all),
                patients_url(segment: 'all'),
                class: "nav-link #{@segment == 'all' ? 'active' : ''}"
      end

      today_pill + follow_up_pill + birthday_pill + all_pill
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
