class DatebooksController < ApplicationController
  before_filter :require_user
  before_filter :require_practice_admin, :except => [:show]
  
  def index
  	# this same variable is already defined in the
    # application controller. Maybe we should think of
    # a way to remove it from there
    # @datebooks = Datebook.mine.order("name")
  end

  def show
    @doctors = Doctor.mine.order("firstname")
    @filtered_by = params[:doctor_id] || nil

    @datebook = Datebook.mine.find params[:id]

    # Detect if this is coming from a mobile device
    @is_mobile = request.user_agent =~ /Mobile|webOS|Android/
  end

  def new
    @datebook = Datebook.new
  end

  def create
    @datebook = Datebook.new(params[:datebook])

    respond_to do |format|
      if @datebook.save
        format.html { redirect_to(datebooks_url, :notice => t(:datebook_created_success_message))}
      else
        format.html { render :action => "new" }
      end
    end
  end

  def edit
    @datebook = Datebook.mine.find params[:id]
  end

  def update
    @datebook = Datebook.mine.find params[:id]

    respond_to do |format|
      if @datebook.update_attributes(params[:datebook])
        format.html { redirect_to(datebooks_url, :notice => t(:datebook_updated_success_message)) }
      else
        format.html { render :action => "edit" }
      end
    end
  end

  def destroy
    @datebook = Datebook.mine.find params[:id]
    @datebook.destroy

    respond_to do |format|
      format.html { redirect_to(datebooks_url) }
    end
  end

end
