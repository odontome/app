class WelcomeController < ApplicationController
  
  layout 'simple'

  def index
    flash.keep 
    if current_user
      if current_user_is_superadmin?
        home_url = practices_admin_url
      else
        home_url = Datebook.mine.first
      end
      redirect_to home_url
    else
      redirect_to :signin
    end
  end

  def privacy
  end

  def terms
  end

end