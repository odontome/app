class AppointmentsController < ApplicationController
  # filters
  before_filter :require_user
  
  # provides
  respond_to :html, :json
  
  #layout
  layout false
  
  def index

    if (params[:doctor_id])
      @appointments = Appointment.find_from_doctor_and_between(params[:doctor_id], params[:start], params[:end])
    else
      @appointments = Appointment.find_between(params[:start], params[:end])
    end
     
     respond_with(@appointments, :methods => ["doctor","patient"])
  end
  
  def new
    @appointment = Appointment.new
    @appointment.starts_at = params[:starts_at]
    @doctors = Doctor.mine.valid
  end
  
  def create
    @appointment = Appointment.new(params[:appointment])
    @appointment.starts_at = Time.at(params[:appointment][:starts_at].to_i)

    # if "as_values_patient_id" is not empty use that, otherwise use "patient_id"
    @appointment.patient_id = Patient.find_or_create_from((params[:as_values_patient_id] != "") ? (params[:as_values_patient_id]) : (params[:appointment][:patient_id]))
    
    respond_to do |format|
      if @appointment.save
          format.js  { } #create.js.erb
      else
          format.js  {
            render_ujs_error(@appointment, I18n.t(:appointment_created_error_message))
          }
      end
    end

  end
  
  def edit
    @appointment = Appointment.mine.find(params[:id])
    @patient = Patient.mine.find(params[:patient_id])
    @doctors = Doctor.mine.valid
  end
  
  def update
    @appointment = Appointment.mine.find(params[:id])
    
    # if "as_values_patient_id" is not empty use that, otherwise use "patient_id"
    if params[:appointment][:patient_id] != nil
      params[:appointment][:patient_id] = Patient.find_or_create_from((params[:as_values_patient_id] != "") ? (params[:as_values_patient_id]) : (params[:appointment][:patient_id]))
    end
    
    respond_to do |format|
      if @appointment.update_attributes(params[:appointment])
        format.js { } # update.js.erb
      else
        format.js  { 
          render_ujs_error(@appointment, I18n.t(:appointment_updated_error_message))
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
            render_ujs_error(@appointment, I18n.t(:appointment_deleted_error_message))
          }
      end
    end
  end
end
