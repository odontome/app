class AppointmentsController < ApplicationController
  # filters
  before_filter :require_user
  
  def index
     @appointments = Appointment.where("starts_at = ? AND ends_at = ? AND practice_id = ?", params[:start], params[:end], UserSession.find.user.practice_id).includes(:patients).order( "starts_at desc")
     
     
  end

end
