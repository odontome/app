module MailHelper
  def simpler_format(text, html_options={}, options={})
      text = ''.html_safe if text.nil?
      start_tag = tag('p', html_options, true)
      text = sanitize(text) unless options[:sanitize] == false
      text.gsub!(/\r\n?/, "\n")                    # \r\n and \r -> \n
      text.gsub!(/\n\n+/, "</p>\n\n#{start_tag}")  # 2+ newline  -> paragraph
      text.gsub!(/([^\n]\n)(?=[^\n])/, '\1<br />') # 1 newline   -> br
      text.insert 0, start_tag
      text.html_safe.safe_concat("</p>")
  end
end