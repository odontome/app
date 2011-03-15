class AppointmentsController < ApplicationController
  # filters
  before_filter :require_user
  
  # provides
  respond_to :html, :json
  
  #layout
  layout nil
  
  def index
     #@appointments = Appointment.where("starts_at > ? AND ends_at < ? AND practice_id = ?", params[:start], params[:end], UserSession.find.user.practice_id).includes(:patients).order( "starts_at desc")
     @appointments = Appointment.all
     
     respond_with(@appointments)
  end
  
  def new
    @appointment = Appointment.new
    @appointment.starts_at = params[:starts_at]
    @doctors = Doctor.mine
  end
  
  # FIXME this could be improved greatly, in a more DRY fashion
  def create
    @appointment = Appointment.new(params[:appointment])
    #@appointment.ends_at = @appointment.starts_at + 6000
    
    # if this value is set, then use it has the patient id
    if (params[:as_values_patient_id] != "")
      @appointment.patient_id = params[:as_values_patient_id]
    # otherwise, we need to create a new patient and pass the id back
    else
      @patient = Patient.new()
      @patient.fullname = params[:appointment][:patient_id]
      @patient.save
      @appointment.patient_id = @patient.id
    end 
    
    respond_to do |format|
      if @appointment.save
          format.js  { } #create.js.erb
      else
          format.js  {
            render :template => "shared/ujs/form_errors.js.erb", 
            :locals =>{
              :item => @appointment, 
              :notice => _("There was an error creating this appointment")
            }
          }
      end
    end
  end

end
