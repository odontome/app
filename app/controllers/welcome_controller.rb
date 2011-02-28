class WelcomeController < ApplicationController
  def index
    if current_user
      if current_user_is_superadmin?
        home_url = practices_url
      else
        home_url = agenda_url
      end
      redirect_to home_url
    else
      redirect_to :signin
    end
  end
end