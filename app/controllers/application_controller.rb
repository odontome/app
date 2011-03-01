class ApplicationController < ActionController::Base
  protect_from_forgery
  helper :all
  filter_parameter_logging :password, :password_confirmation
  helper_method :current_session, :current_user, :current_user_is_admin?, :user_is_admin?

  before_filter :find_practice_object
  before_filter :set_gettext_locale
  
  private
    def current_user_session
      return @current_user_session if defined?(@current_user_session)
      @current_user_session = UserSession.find
    end

    def current_user
      return @current_user if defined?(@current_user)
      @current_user = current_user_session && current_user_session.user
    end
  
    def current_user_is_admin?
      if current_user
        return true if current_user.roles.include?("admin")
      end
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
        flash[:notice] = "You must be logged out to access this page"
        redirect_to practices_path
        return false
      end
    end

    def store_location
      session[:return_to] = request.request_uri
    end
    
    def redirect_back_or_default(default)
      redirect_to(session[:return_to] || default)
      session[:return_to] = nil
    end

    def require_superadmin
      if current_user
        redirect_back_or_default("/") unless current_user_is_superadmin?
        return false
      end
    end
    
    def find_practice_object
      if current_user
        # superadmins doesn't have a Related Practice
        @practice = current_user.practice unless current_user_is_superadmin?
      end
    end

end
