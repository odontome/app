# Overwrite the error messages
ActionView::Base.field_error_proc = proc do |html_tag, _instance|
  if html_tag.include? 'input'
    %(<span class="has-error">#{html_tag}</span>).html_safe
  else
    html_tag.html_safe
  end
end
