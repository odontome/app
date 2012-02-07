class DatebookController < ApplicationController
  before_filter :require_user
  
  def show
    @doctors = Doctor.mine.order("firstname")
    
    # Detect if this is coming from a mobile device
    mobile_device = request.user_agent =~ /Mobile|webOS|Android/
    # If it is, render a simplified calendar
    if !mobile_device.nil?
    	render "mobile"
    end
  end

end
