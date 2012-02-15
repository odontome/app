module ApplicationHelper
  def extract_text_from_gettext(text)
    return text.match(/\_\((\'|\")(.*)(\'|\")\)/).captures[1]
  end
  
  # overwrite to the pagination plugin
  def paginated_letter(available_letters, letter)
    if available_letters.include?(letter)
      link_to(letter, "#{request.path}?letter=#{letter}")
    else
      content_tag :span, letter
    end
  end
  
  def number_to_currency_with_currency(number)
    number_to_currency(number, :unit => @current_user.practice.currency_unit)
  end
  
  def new_tag
  	content_tag :span, _("new"), :class => "radius red label"
  end
  
  def incomplete_tag
  	content_tag :span, _("incomplete"), :class => "radius red label"
  end
end
