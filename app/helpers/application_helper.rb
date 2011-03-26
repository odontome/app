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
end
