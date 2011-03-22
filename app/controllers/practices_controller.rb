class PracticesController < ApplicationController

  before_filter :require_user, :only =>  [:index, :destroy, :edit, :settings, :show, :close]
  before_filter :require_no_user, :only => [:new, :create]
  before_filter :require_superadmin, :only => [:index, :destroy, :edit]
  
  def index
    @practices = Practice.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @practices }
    end
  end

  def show
    @practice = Practice.find(current_user.practice_id)

    respond_to do |format|
      format.html # show.html.erb
    end
  end

  def new
    @practice = Practice.new
    @practice.users.build
    @user = User.new
  end

  def edit
    @practice = Practice.find(params[:id])
  end

  def create
    @practice = Practice.new(params[:practice])
    
    respond_to do |format|
      if @practice.save
        format.html { redirect_to(practice_path, :notice => _('Your practice is now active! You can start to set everything up in here.')) }
      else
        format.html { render :action => "new", :as => :signup }
      end
    end
  end

  def update
    @practice = Practice.find(params[:id])
    session[:locale] = params[:practice][:locale]
    
    respond_to do |format|
      if @practice.update_attributes(params[:practice])
        format.html { redirect_to(practice_url, :notice => _('Your practice settings were successfully updated.')) }
      else
        format.html { render :action => "edit" }
      end
    end
  end
  
  def change_to_free_plan
    if current_user.practice.patients.count > PLANS['free']['number_of_patients']
      flash[:alert] = _("We are sorry. Your account cannot be changed to the Free Plan because your practice exceeds the number of patients allowed by it. You'll have to delete some patients first and Unsubscribe your current plan.")
    elsif current_user.practice.status == "active"
      # "active" means that the account has an active plan in Paypal
      flash[:alert] = _("We are sorry. Your account cannot be changed to the Free Plan. You have to first Unsubscribe from your current plan through your Practice Settings or Paypal.")
    elsif current_user.practice.status == "expiring"
      # "expiring" means that confirmation of cancellation has been received from Paypal.
      practice = Practice.find(current_user.practice_id)
      practice.set_plan_id_and_number_of_patients(1)
      practice.save
      flash.discard
      flash[:notice] = _("Your practice's account has been changed to the Free Plan!")
    end
    redirect_to practice_settings_url
  end

  def close
    if current_user.practice.status == "active"
      # "active" means that the account has an active plan in Paypal
      flash[:alert] = _("Please Unsubscribe first from your current plan to close your account so Paypal won't charge you on the next billing cycle. Please try again once your plan it's cancelled.")
      redirect_to practice_settings_url
    else
      @practice = Practice.find_by_id(current_user.practice_id)
      @practice.set_as_cancelled
      if @practice.save
        current_user_session.destroy
        flash.discard
        redirect_to signin_url, :notice => _("Your account is now beign closed and is no longer possible to access it. Please contact us if you need assistance.")
      else
        @practice.errors[:base] << _("An error has ocurred. We couldn't close your account. Please contact us.")
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
    @practice = Practice.includes(:plan).find(current_user.practice_id)
    @practice_patients_count = @practice.patients.count
  end

end
