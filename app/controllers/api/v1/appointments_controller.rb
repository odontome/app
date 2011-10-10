class Api::V1::AppointmentsController < Api::V1::BaseController
  
  before_filter :find_appointment, :only => [:show, :update, :destroy]
  
  def index
    respond_with(Appointment.find_between(params[:starts_at], params[:ends_at]), :methods => ["doctor","patient"])
  end
  
  def show
    respond_with(@appointment, :methods => ["doctor","patient"])
  end
  
  def create
    appointment = Appointment.create(params[:appointment])
    
    if appointment.valid?
      respond_with(appointment, :location => api_v1_appointment_path(appointment))
    else
      respond_with(appointment)
  	end 
  end
  
  def update
  	@appointment.update_attributes(params[:appointment])
		respond_with(@appointment)
  end
  
  def destroy
    @appointment.destroy
    respond_with(@appointment)
  end
  
  private
  
  def find_appointment
  	@appointment = Appointment.mine.find(params[:id])
  	rescue ActiveRecord::RecordNotFound
  		error = { :error => "The appointment you were looking for could not be found."}
  		respond_with(error, :status => 404)
  end
  
end