class UserSessionsController < ApplicationController
  #before_filter :require_no_user, :only => [:new, :create]
  before_filter :require_user, :only => :destroy

  def new
    @user_session = UserSession.new
  end

  def create
    @user_session = UserSession.with_scope(:find_options => {:include => :practice}) do
      UserSession.new(params[:user_session])
    end

    respond_to do |format|
      if @user_session.save
        session[:locale] = @user_session.user.preferred_language

        # record the signed in
        @mixpanel.track(@user_session.user.email, 'Signed in')
        @mixpanel.people.set(@user_session.user.email, {
            '$first_name' => @user_session.user.firstname,
            '$last_name' => @user_session.user.lastname,
            '$email' => @user_session.user.email,
            '$language' => @user_session.user.preferred_language
        })

        format.html { redirect_to(root_url) }
      else
        format.html { render :action => "new" }
      end
    end

  end

  def destroy
    current_user_session.destroy
    redirect_to root_url
  end
end
