class WelcomeController < ApplicationController
  
  layout 'simple'

  def index
    flash.keep 
    if current_user
      if current_user_is_superadmin?
        home_url = practices_admin_url
      else
        home_url = datebook_url
      end
      redirect_to home_url
    else
      redirect_to :signin
    end
  end

  def set_session_time_zone
    session[:time_zone_name] = params[:detected_timezone]
    render :nothing => true
  end

  def privacy
  end

  def terms
  end

end