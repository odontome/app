class UserSessionsController < ApplicationController
  #before_filter :require_no_user, :only => [:new, :create]
  before_action :require_user, :only => :destroy

  def new
    # Unused
  end

  def create  
    respond_to do |format|
      # Look up User in db by the email address submitted to the login form and
      # convert to lowercase to match email in db in case they had caps lock on:
      user = User.find_by(email: params[:signin][:email].downcase)
      
      # Verify user exists in db and run has_secure_password's .authenticate() 
      # method to see if the password submitted on the login form was correct: 
      if user && user.authenticate(params[:signin][:password]) 
        # Save the user in that user's session cookie:
        session[:user] = user
        format.html { redirect_to(root_url) }
      else
        # if email or password incorrect, re-render login page:
        format.html { render :action => "new" }
      end
    end
  end

  def destroy
    # delete the saved user_id key/value from the cookie:
    session.clear
    redirect_to root_url
  end
end
