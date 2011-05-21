class ApplicationController < ActionController::Base
  
  protect_from_forgery

  helper :all
  filter_parameter_logging :password, :password_confirmation
  helper_method :current_session, :current_user, :user_is_admin?

  before_filter :check_account_status
  before_filter :set_locale
  before_filter :set_timezone  
  
  def check_account_status
    if current_user 
      if current_user.practice.status == "cancelled"
        current_user_session.destroy
        redirect_to signin_url, :alert => _("Your account has been cancelled and is no longer possible to access it. Please contact us if you need assistance.")
      elsif current_user.practice.status == "expiring"
        flash[:alert] = _("Your account is in the process of being cancelled and is going to expire at the end of your current billing cycle. Please be aware that your account will be deleted. You can however change your practice to the Free Plan if you have less than the allowed patients for that plan or subscribe again a new plan.")
      elsif current_user.practice.status == "payment_due"
        flash[:alert] = _("Your account is Pending Payment. We have unsuccesfully tried to bill your Paypal account and we'll try again soon. Please be aware that after 3 failed billing attemps your account will be closed. Please check your account with Paypal, maybe your card has expired.")
      end
    end
  end


  def set_locale
    if current_user
      session[:locale] = I18n.locale = FastGettext.set_locale(session[:locale])
    else
      session[:locale] = I18n.locale = FastGettext.set_locale(compatible_language_from(AVAILABLE_LOCALES))
    end
  end
  
  def set_timezone
    if current_user
      Time.zone = current_user.practice.timezone
    end
  end
  

  # Returns a sorted array based on user preference in HTTP_ACCEPT_LANGUAGE.
  # Browsers send this HTTP header, so don't think this is holy.
  def user_preferred_languages
    @user_preferred_languages ||= env['HTTP_ACCEPT_LANGUAGE'].split(',').collect do |l|
      l += ';q=1.0' unless l =~ /;q=\d+\.\d+$/
      l.split(';q=')
    end.sort do |x,y|
      raise "Not correctly formatted" unless x.first =~ /^[a-z\-]+$/i
      y.last.to_f <=> x.last.to_f
    end.collect do |l|
      l.first.downcase.gsub(/-[a-z]+$/i) { |x| x.upcase }
    end
  rescue # Just rescue anything if the browser messed up badly.
    []
  end

  # Finds the locale specifically requested by the browser.
  def preferred_language_from(array)
    (user_preferred_languages & array.collect { |i| i.to_s }).first
  end

  # Returns the first of the user_preferred_languages that is compatible
  # with the available locales. Ignores region.
  def compatible_language_from(array)
    user_preferred_languages.map do |x|
      x = x.to_s.split("-")[0]
      array.find do |y|
        y.to_s.split("-")[0] == x
      end
    end.compact.first
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
  
    def user_is_admin?(user)
      return true if user.roles.include?("admin")
    end

    def current_user_is_superadmin?
      if current_user
        return true if current_user.roles.include?("superadmin")
      end
    end
  
    def require_user
      unless current_user
        store_location
        flash[:notice] = _("You must be logged in to access this page")
        redirect_to signin_path
        return false
      end
    end

    def require_no_user
      if current_user
        store_location
        flash[:notice] = _("You must be logged out to access this page")
        redirect_to root_path
        return false
      end
    end

    def store_location
      session[:return_to] = request.request_uri
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
        return false
      end
    end

    def require_practice_admin
      if current_user
        unless user_is_admin?(current_user)
          redirect_back_or_default("/", _('Sorry, you need to be an administrator of your practice to do that.'))
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

end