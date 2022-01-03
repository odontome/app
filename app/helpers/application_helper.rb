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

  def avatar_url(email, size = 96)
    email ||= 'user_has_no@email.com'
    gravatar_id = Digest::MD5.hexdigest(email.downcase)
    "https://gravatar.com/avatar/#{gravatar_id}?s=#{size}&d=identicon"
  end

  def is_current_datebook?(id)
    params[:controller] == 'datebooks' && params[:id] == id.to_s
  end

  def is_active_tab?(tab)
    allowed_values = [:datebooks, :patients, :doctors, :practices]
    unless tab.in?(allowed_values)
      raise "#{tab} is invalid. Allowed values: #{allowed_values.join(', ')}."
    end

    controller.controller_name == tab.to_s ? 'active' : ''
  end

  def component(name, *options, &block)
    render("components/#{name}", *options, &block)
  end
end
