# frozen_string_literal: true

module ApplicationHelper
  def number_to_currency_with_code(number, code = 'USD')
    case code
    when 'usd'
      number_to_currency(number, unit: 'US$', precision: 2)
    when 'cad'
      number_to_currency(number, unit: 'CA$', precision: 2)
    when 'eur'
      number_to_currency(number, unit: '€', precision: 2)
    when 'mxn'
      number_to_currency(number, unit: 'MX$', precision: 2)
    else
      number_to_currency(number, unit: '', precision: 2)
    end
  end

  def label_tag(message, color = :azure)
    allowed_colors = %i[green red azure]
    raise "#{color} is invalid. Allowed values: #{allowed_colors.join(', ')}." unless color.in?(allowed_colors)

    content_tag 'span', message, class: "badge bg-#{color}-lt"
  end

  def value_tag(title, value)
    aggregated_value = content_tag 'strong', title

    if value.blank?
      content_tag 'div' do
        aggregated_value.concat content_tag 'div', '—', class: 'form-control-plaintext text-muted'
      end
    else
      content_tag 'div' do
        aggregated_value.concat content_tag 'div', value, class: 'form-control-plaintext'
      end
    end
  end

  def help_tag(value)
    content_tag :span, '?', class: 'form-help',
                            data: { "bs-toggle": 'popover', "bs-placement": 'top', "bs-content": value, "bs-html": true }
  end

  def is_current_datebook?(id)
    params[:controller] == 'datebooks' && params[:id] == id.to_s
  end

  def is_active_tab?(tabs)
    allowed_values = %i[datebooks patients doctors practices users treatments reviews audits payments]

    tabs = Array(tabs).map(&:to_s)

    invalid = tabs.reject { |t| allowed_values.map(&:to_s).include?(t) }
    raise "#{invalid.join(', ')} are invalid. Allowed values: #{allowed_values.join(', ')}." if invalid.any?

    tabs.include?(controller.controller_name) ? 'active' : ''
  end

  def component(name, *options, &block)
    render("components/#{name}", *options, &block)
  end

  def parse_version_object_data(version)
    return nil unless version.object.present?

    begin
      JSON.parse(version.object)
    rescue JSON::ParserError => e
      Rails.logger.error "Failed to parse version object data: #{e.message}"
      nil
    end
  end

  def parse_version_changes_data(version)
    return nil unless version.object_changes.present?

    begin
      JSON.parse(version.object_changes)
    rescue JSON::ParserError => e
      Rails.logger.error "Failed to parse version changes data: #{e.message}"
      nil
    end
  end

  def deleted_item_display_name(version)
    return I18n.t('audits.deleted_item_with_id', id: version.item_id) unless version.object.present?

    object_data = parse_version_object_data(version)
    return I18n.t('audits.deleted_item_with_id', id: version.item_id) unless object_data.is_a?(Hash)

    case version.item_type
    when 'Patient', 'Doctor', 'User'
      if object_data['firstname'] && object_data['lastname']
        I18n.t('audits.deleted_person', name: "#{object_data['firstname']} #{object_data['lastname']}")
      else
        I18n.t('audits.deleted_item_with_id', id: version.item_id)
      end
    when 'Practice'
      if object_data['name']
        I18n.t('audits.deleted_practice', name: object_data['name'])
      else
        I18n.t('audits.deleted_item_with_id', id: version.item_id)
      end
    when 'Treatment'
      if object_data['name']
        I18n.t('audits.deleted_treatment', name: object_data['name'])
      else
        I18n.t('audits.deleted_item_with_id', id: version.item_id)
      end
    when 'Datebook'
      if object_data['name']
        I18n.t('audits.deleted_datebook', name: object_data['name'])
      else
        I18n.t('audits.deleted_item_with_id', id: version.item_id)
      end
    when 'Appointment'
      if object_data['notes'].present?
        I18n.t('audits.deleted_appointment_with_notes', notes: object_data['notes'])
      else
        I18n.t('audits.deleted_appointment_with_id', id: version.item_id)
      end
    else
      I18n.t('audits.deleted_item_with_id', id: version.item_id)
    end
  end

  def audit_item_link(item, version)
    return deleted_item_display_name(version) unless item

    # Use the correct path helper depending on nesting
    destination = case version.item_type
                  when 'Appointment'
                    [item.datebook, item]
                  when 'Balance'
                    patient_balances_path(item.patient)
                  else
                    item
                  end

    link_to audit_item_display_name(item, version), destination
  end

  private

  def audit_item_display_name(item, version)
    case version.item_type
    when 'Patient', 'Doctor', 'User'
      item.fullname
    when 'Practice'
      item.name
    when 'Treatment', 'Datebook'
      item.name
    when 'Appointment'
      item.notes.present? ? item.notes : "Appointment ##{item.id}"
    else
      "ID: #{version.item_id}"
    end
  end

  def connect_account_status_i18n(status)
    case status
    when 'complete'
      I18n.t 'stripe_account.account.status.complete'
    when 'pending_review'
      I18n.t 'stripe_account.account.status.pending_review'
    when 'pending'
      I18n.t 'stripe_account.account.status.pending'
    when 'not_started'
      I18n.t 'stripe_account.account.status.not_started'
    when 'disabled'
      I18n.t 'stripe_account.account.status.disabled'
    else
      I18n.t 'stripe_account.account.status.unknown'
    end
  end

  def connect_account_status_badge_class(status)
    case status
    when 'complete'
      'success'
    when 'pending_review'
      'warning'
    when 'pending'
      'info'
    when 'not_started'
      'secondary'
    when 'disabled'
      'danger'
    else
      'secondary'
    end
  end

  def active_announcements
    Announcement.active_for_user(current_user)
  end
end
