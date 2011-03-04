module ApplicationHelper
  def extract_text_from_gettext(text)
    return text.match(/\_\((\'|\")(.*)(\'|\")\)/).captures[1]
  end
end
