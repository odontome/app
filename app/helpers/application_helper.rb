# frozen_string_literal: true

module ApplicationHelper
  def number_to_currency_with_symbol(number, precision = 2)
    number_to_currency(number, unit: @current_user.practice.currency_unit, precision: precision)
  end

  def incomplete_tag
    content_tag :span, t(:incomplete), class: 'label label-danger'
  end

  def label_tag(message, color = :azure)
    allowed_colors = [:green, :red, :azure]
    unless color.in?(allowed_colors)
      raise "#{color} is invalid. Allowed values: #{allowed_colors.join(', ')}."
    end

    content_tag 'span', message, class: "badge bg-#{color.to_s}-lt"
  end

  def avatar_url(email, size = 96)
    email ||= 'user_has_no@email.com'
    gravatar_id = Digest::MD5.hexdigest(email.downcase)
    "https://gravatar.com/avatar/#{gravatar_id}?s=#{size}&d=identicon"
  end

  def is_current_datebook?(id)
    params[:controller] == 'datebooks' && params[:id] == id.to_s
  end
end
