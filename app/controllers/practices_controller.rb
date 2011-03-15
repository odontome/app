class PracticesController < ApplicationController

  before_filter :require_user, :only =>  [:index, :destroy, :edit, :settings, :show]
  before_filter :require_no_user, :only => [:new, :create]
  before_filter :require_superadmin, :only => [:index, :destroy, :edit]
  before_filter :verify_correct_plan_id_or_redirect_to_free, :only => [:new]
  
  # GET /practices
  # GET /practices.xml
  def index
    @practices = Practice.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @practices }
    end
  end

  # GET /practices/1
  # GET /practices/1.xml
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
    @plan_description = PLANS[params[:id]]['description']
  end

  # GET /practices/1/edit
  def edit
    @practice = Practice.find(params[:id])
  end

  # POST /practices
  # POST /practices.xml
  def create
    @practice = Practice.new(params[:practice])
    
    respond_to do |format|
      if @practice.save
        format.html { redirect_to(practice_path, :notice => _('Practice was successfully created.')) }
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
        format.html { redirect_to(practice_url, :notice => _('Practice was successfully updated.')) }
      else
        format.html { render :action => "edit" }
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
    @practice_users_count = @practice.users.count
  end

  private
  def verify_correct_plan_id_or_redirect_to_free
    if params[:id].nil?
      redirect_to "/signup/free" 
    else
      if PLANS.include?(params[:id])
        @plan_name = PLANS[params[:id]]['name']
      else
        redirect_to "/signup/free"
      end
  	end
  end

end
