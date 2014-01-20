module ApplicationHelper
  
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
  	content_tag :span, t(:new), :class => "label label-primary"
  end
  
  def incomplete_tag
  	content_tag :span, t(:incomplete), :class => "label label-danger"
  end

  def avatar_url(email, size = 96)
  	email = email || "user_has_no@email.com"
  	default_url = "#{root_url}images/avatar.jpg"
  	gravatar_id = Digest::MD5.hexdigest(email.downcase)
  	"http://gravatar.com/avatar/#{gravatar_id}?s=#{size}"
  end

  def is_current_datebook?(id)
    params[:controller] == "datebooks" && params[:id] == id.to_s
  end
  
end
