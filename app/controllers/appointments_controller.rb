class AppointmentsController < ApplicationController
  # filters
  before_filter :require_user
  
  def index
     @appointments = Appointment.find(:includes => "patient", :where("starts_at = ? AND ends_at = ? AND practice_id = ?", params[:start], params[:end], UserSession.find.user.practice_id), :order => "starts_at DESC")
     
     respond_to do |format|
       format.json
     end
  end

end
