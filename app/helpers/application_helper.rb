# frozen_string_literal: true

module ApplicationHelper
  # overwrite to the pagination plugin
  def paginated_letter(available_letters, letter)
    if available_letters.include?(letter)
      link_to(letter, "#{request.path}?letter=#{letter}")
    else
      content_tag :span, letter
    end
  end

  def number_to_currency_with_symbol(number, precision = 2)
    number_to_currency(number, unit: @current_user.practice.currency_unit, precision: precision)
  end

  def incomplete_tag
    content_tag :span, t(:incomplete), class: 'label label-danger'
  end

  def label_tag(message, type = 'info')
    content_tag 'sub', message, class: "label label-#{type}"
  end

  def avatar_url(email, size = 96)
    email ||= 'user_has_no@email.com'
    gravatar_id = Digest::MD5.hexdigest(email.downcase)
    "https://gravatar.com/avatar/#{gravatar_id}?s=#{size}&d=retro"
  end

  def is_current_datebook?(id)
    params[:controller] == 'datebooks' && params[:id] == id.to_s
  end
end
