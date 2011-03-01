class PracticesController < ApplicationController

  before_filter :require_no_user, :only => [:new, :create]
  before_filter :require_superadmin, :only => [:index, :destroy]

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
        format.html { redirect_to(practice_path, :notice => 'Practice was successfully created.') }
      else
        format.html { render :action => "new", :as => :signup }
      end
    end
  end

  # PUT /practices/1
  # PUT /practices/1.xml
  def update
    @practice = Practice.find(params[:id])

    respond_to do |format|
      if @practice.update_attributes(params[:practice])
        format.html { redirect_to(@practice, :notice => 'Practice was successfully updated.') }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @practice.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /practices/1
  # DELETE /practices/1.xml
  def destroy
    @practice = Practice.find(params[:id])
    @practice.destroy

    respond_to do |format|
      format.html { redirect_to(practices_url) }
      format.xml  { head :ok }
    end
  end
end
