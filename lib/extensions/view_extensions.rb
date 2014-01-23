# Overwrite the error messages
ActionView::Base.field_error_proc = Proc.new do |html_tag, instance|	
	if html_tag.include? "input"
		%(<span class="has-error">#{html_tag}</span>).html_safe
	else
		html_tag.html_safe
	end
end