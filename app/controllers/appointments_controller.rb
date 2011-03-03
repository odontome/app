class AppointmentsController < ApplicationController
  # filters
  before_filter :require_user
  
  # provides
  respond_to :html, :json
  
  #layout
  layout nil
  
  def index
     @appointments = Appointment.where("starts_at > ? AND ends_at < ? AND practice_id = ?", params[:start], params[:end], UserSession.find.user.practice_id).includes(:patients).order( "starts_at desc")
     
     respond_with(@appointments)
  end
  
  def new
    @appointment = Appointment.new
    @appointment.starts_at = params[:starts_at]
    @doctors = Doctor.mine
  end

end
