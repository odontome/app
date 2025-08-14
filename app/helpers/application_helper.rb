# frozen_string_literal: true

module ApplicationHelper
  def number_to_currency_with_symbol(number, precision = 2)
    number_to_currency(number, unit: @current_user.practice.currency_unit, precision: precision)
  end

  def label_tag(message, color = :azure)
    allowed_colors = [:green, :red, :azure]
    unless color.in?(allowed_colors)
      raise "#{color} is invalid. Allowed values: #{allowed_colors.join(', ')}."
    end

    content_tag 'span', message, class: "badge bg-#{color.to_s}-lt"
  end

  def value_tag(title, value)
    aggregated_value = content_tag "strong", title

    if value.blank?
      content_tag "div" do
        aggregated_value.concat content_tag "div", "—", class: "form-control-plaintext text-muted"
      end
    else
      content_tag "div" do
        aggregated_value.concat content_tag "div", value, class: "form-control-plaintext"
      end
    end
  end

  def help_tag(value)
    content_tag :span, "?", class: 'form-help', data: {"bs-toggle": "popover", "bs-placement": "top", "bs-content": value, "bs-html": true}
  end

  def is_current_datebook?(id)
    params[:controller] == 'datebooks' && params[:id] == id.to_s
  end

  def is_active_tab?(tab)
    allowed_values = [:datebooks, :patients, :doctors, :practices, :users, :treatments, :reviews, :audits]
    unless tab.in?(allowed_values)
      raise "#{tab} is invalid. Allowed values: #{allowed_values.join(', ')}."
    end

    controller.controller_name == tab.to_s ? 'active' : ''
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
    return "[Deleted] ID: #{version.item_id}" unless version.object.present?
    
    object_data = parse_version_object_data(version)
    return "[Deleted] ID: #{version.item_id}" unless object_data.is_a?(Hash)
    
    case version.item_type
    when 'Patient', 'Doctor', 'User'
      if object_data['firstname'] && object_data['lastname']
        "#{object_data['firstname']} #{object_data['lastname']} [Deleted]"
      else
        "[Deleted] ID: #{version.item_id}"
      end
    when 'Practice'
      object_data['name'] ? "#{object_data['name']} [Deleted]" : "[Deleted] ID: #{version.item_id}"
    when 'Treatment'
      object_data['name'] ? "#{object_data['name']} [Deleted]" : "[Deleted] ID: #{version.item_id}"
    when 'Datebook'
      object_data['name'] ? "#{object_data['name']} [Deleted]" : "[Deleted] ID: #{version.item_id}"
    when 'Appointment'
      if object_data['notes'].present?
        "#{object_data['notes']} [Deleted]"
      else
        "Appointment ##{version.item_id} [Deleted]"
      end
    else
      "[Deleted] ID: #{version.item_id}"
    end
  end
end
