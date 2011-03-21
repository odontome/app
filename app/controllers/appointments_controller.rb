class AppointmentsController < ApplicationController
  # filters
  before_filter :require_user
  
  # provides
  respond_to :html, :json
  
  #layout
  layout nil
  
  def index
     @appointments = Appointment.find_between(params[:start], params[:end])
     
     respond_with(@appointments)
  end
  
  def new
    @appointment = Appointment.new
    @appointment.starts_at = params[:starts_at]
    @doctors = Doctor.mine
  end
  
  def create
    @appointment = Appointment.new(params[:appointment])
    #@appointment.starts_at = Time.at(params[:appointment][:starts_at].to_i)

    # if "as_values_patient_id" is not empty use that, otherwise use "patient_id"
    @appointment.patient_id = Patient.find_or_create_from((params[:as_values_patient_id] != "") ? (params[:as_values_patient_id]) : (params[:appointment][:patient_id]))
    
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
    @appointment = Appointment.mine.find(params[:id])
    
    # if "as_values_patient_id" is not empty use that, otherwise use "patient_id"
    if params[:type] == "edit"
      params[:appointment][:patient_id] = Patient.find_or_create_from((params[:as_values_patient_id] != "") ? (params[:as_values_patient_id]) : (params[:appointment][:patient_id]))
    end
    
    respond_to do |format|
      if @appointment.update_attributes(params[:appointment])
        format.js { } # update.js.erb
      else
        format.js  { 
          render_ujs_error(@appointment, _("There was an error updating this appointment"))
        }
      end
    end
  end
  
  def destroy
    @appointment = Appointment.mine.find(params[:id])

    respond_to do |format|
      if @appointment.destroy
          format.js { render :action => :create } # reuses create.js.erb
      else
          format.js  {
            render_ujs_error(@appointment, _("There was an error deleting this appointment"))
          }
      end
    end
  end
end
