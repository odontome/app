class PracticesController < ApplicationController

  before_filter :require_user, :only =>  [:index, :destroy, :edit, :settings, :show, :close]
  before_filter :require_no_user, :only => [:new, :create]
  before_filter :require_superadmin, :only => [:index, :destroy, :edit]
  before_filter :require_practice_admin, :only => [:settings, :update, :change_to_free_plan, :close]
  
  def index
    @practices = Practice.all
  end

  def show
    @practice = current_user.practice
    @is_user_admin = current_user.roles.include?("admin")
  end

  def new
    @practice = Practice.new
    @practice.users.build
    @user = User.new
    
    render :layout => "user_sessions"
  end

  def edit
    @practice = current_user.practice
  end

  def create
    @practice = Practice.new(params[:practice])
    @practice.locale = session[:locale]
    @practice.timezone = session[:time_zone_name]
    
    respond_to do |format|
      if @practice.save
        PracticeMailer.welcome_email(@practice).deliver
        format.html { redirect_to(practice_path, :notice => I18n.t(:practice_created_success_message)) }
      else
        format.html { render :action => "new", :as => :signup, :layout => "user_sessions" }
      end
    end
  end

  def update
    @practice = current_user.practice
    session[:locale] = params[:practice][:locale]
    
    respond_to do |format|
      if @practice.update_attributes(params[:practice])
        format.html { redirect_to(practice_url, :notice => t(:practice_updated_success_message)) }
      else
        format.html { render :action => "settings" }
      end
    end
  end
  
  def cancel
  end

  def close
    if current_user.practice.status == "active"
      # "active" means that the account has an active plan in Paypal
      flash[:alert] = I18n.t(:practice_close_active_message)
      redirect_to practice_settings_url
    else
      @practice = current_user.practice
      @practice.set_as_cancelled
      if @practice.save
        current_user_session.destroy
        flash.discard
        redirect_to signin_url, :notice => I18n.t(:practice_close_success_message)
      else
        @practice.errors[:base] << I18n.t(:practice_close_error_message)
        redirect_to practice_settings_url
      end
    end
  end

  def destroy
    @practice = Practice.find(params[:id])
    @practice.destroy

    respond_to do |format|
      format.html { redirect_to(practices_url) }
      format.xml  { head :ok }
    end
  end

  def settings
    @practice = current_user.practice
    @practice_patients_count = @practice.patients.count
  end

end
