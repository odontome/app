class DatebookController < ApplicationController
  before_filter :require_user
  
  def show
    @doctors = Doctor.mine.order("firstname")
    @filtered_by = params[:doctor_id] || nil

    # Detect if this is coming from a mobile device
    @is_mobile = request.user_agent =~ /Mobile|webOS|Android/
  end

end
