class DatebooksController < ApplicationController
  before_filter :require_user
  
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

end
