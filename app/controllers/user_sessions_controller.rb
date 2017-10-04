class UserSessionsController < ApplicationController
  #before_filter :require_no_user, :only => [:new, :create]
  before_action :require_user, :only => :destroy

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

        user = @user_session.user
        practice = @user_session.user.practice

        # record the signed in
        MIXPANEL_CLIENT.track(user.email, 'Signed in')
        MIXPANEL_CLIENT.people.set(user.email, {
            '$first_name' => user.firstname,
            '$last_name' => user.lastname,
            '$email' => user.email,
            '$language' => practice.locale,
            '$timezone' => practice.timezone,
            'Practice' => practice.name,
            'Number of patients' => practice.patients_count,
            'Number of doctors' => practice.doctors_count,
            'Number of datebooks' => practice.datebooks_count
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
