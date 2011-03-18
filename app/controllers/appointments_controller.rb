class AppointmentsController < ApplicationController
  # filters
  before_filter :require_user
  
  # provides
  respond_to :html, :json
  
  #layout
  layout nil
  
  def index
     @appointments = Appointment.find_for_calendar(params[:start], params[:end])
     
     respond_with(@appointments)
  end
  
  def new
    @appointment = Appointment.new
    @appointment.starts_at = params[:starts_at]
    @doctors = Doctor.mine
  end
  
  def create
    @appointment = Appointment.new(params[:appointment])
    @appointment.starts_at = Time.at(params[:appointment][:starts_at].to_i)
    
    # if this value is set, then use it has the patient id
    if (params[:as_values_patient_id] != "")
      @appointment.patient_id = params[:as_values_patient_id]
    # otherwise, we need to create a new patient and pass the id back
    else
      @patient = Patient.new()
      @patient.fullname = params[:appointment][:patient_id]
      # set the practice_id manually because validation (and callbacks apparently as well) are skipped
      @patient.practice_id = UserSession.find.user.practice_id
      # skip validation when saving this patient
      @patient.save!(:validate => false)
      @appointment.patient_id = @patient.id
    end 
    
    respond_to do |format|
      if @appointment.save
          format.js  { } #create.js.erb
      else
          format.js  {
            render_ujs_error(@appointment, _("There was an error creating this appointment"))
          }
      end
    end
  end
  
  def edit
    @appointment = Appointment.mine.find(params[:id])
    @patient = Patient.mine.find(params[:patient_id])
    @doctors = Doctor.mine
  end
  
  def update
    
  end
  
  def destroy
    @appointment = Appointment.mine.find(params[:id])

    respond_to do |format|
      if @appointment.destroy
          format.js  { } #destroy.js.erb
      else
          format.js  {
            render_ujs_error(@appointment, _("There was an error deleting this appointment"))
          }
      end
    end
  end
end
