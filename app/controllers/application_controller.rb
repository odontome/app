class ApplicationController < ActionController::Base
  
  protect_from_forgery

  helper :all

  helper_method :current_session, :current_user, :user_is_admin?

  before_filter :check_account_status
  before_filter :set_locale
  before_filter :set_timezone  
  before_filter :find_datebooks
  
  def check_account_status
    if current_user 
      if current_user.practice.status == "cancelled"
        current_user_session.destroy
        redirect_to signin_url, :alert => I18n.t(:account_cancelled)
      end
    end
  end

  def set_locale
    I18n.locale = session[:locale] || I18n.default_locale
  end
  
  def set_timezone
    if current_user
      Time.zone = current_user.practice.timezone
    end
  end
    
  private

  def current_user_session
    return @current_user_session if defined?(@current_user_session)
    @current_user_session = UserSession.find
  end

  def current_user
    return @current_user if defined?(@current_user)
    @current_user = current_user_session && current_user_session.user
  end

  def user_is_admin?(user = current_user)
    return true if user.roles.include?("admin")
  end

  def find_datebooks
    if current_user 
      @datebooks = Datebook.mine.order("name")
    end
  end

  def current_user_is_superadmin?
    if current_user
      return true if current_user.roles.include?("superadmin")
    end
  end

  def require_user
    unless current_user
      store_location
      flash[:notice] = t :not_logged_in
      redirect_to signin_path
      return false
    end
  end

  def require_no_user
    if current_user
      store_location
      flash[:notice] = t :not_logged_in
      redirect_to root_path
      return false
    end
  end

  def store_location
    session[:return_to] = request.url
  end
  
  def redirect_back_or_default(default, message=nil)
    return_to = session[:return_to] || default
    redirect_to(return_to, :alert => message)
    session[:return_to] = nil
  end

  def require_superadmin
  	    	
    if current_user	
      redirect_back_or_default("/") unless current_user_is_superadmin?
      return false
    else
    	redirect_back_or_default("/")
      return false
    end
  end

  def require_practice_admin
    if current_user
      unless user_is_admin?(current_user)
        redirect_back_or_default("/401", I18n.t(:admin_credentials_required))
        return false
      end
    else
      return false
    end
  end

  def render_ujs_error(object, message)
    render :template => "shared/ujs/form_errors.js.erb", 
      :locals =>{
      :item => object, 
      :notice => message
    }
  end

  def decipher(value)
    cipher = Gibberish::AES.new(Rails.configuration.secret_token)
    return cipher.dec value
  end

  def cipher(value)
    cipher = Gibberish::AES.new(Rails.configuration.secret_token)
    return cipher.enc value
  end

end