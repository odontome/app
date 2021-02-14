class AppointmentsController < ApplicationController
  # filters
  before_action :require_user, except: :show

  # layout
  layout false

  def index
    datebook = Datebook.with_practice(current_user.practice_id).find(params[:datebook_id])

    @appointments = if params[:doctor_id]
                      datebook.appointments.find_from_doctor_and_between(params[:doctor_id], params[:start],
                                                                         params[:end])
                    else
                      datebook.appointments.find_between(params[:start], params[:end])
                    end

    respond_to do |format|
      format.html # index.html
      format.json { render json: @appointments, methods: %w[doctor patient] }
    end
  end

  def new
    @datebook = Datebook.with_practice(current_user.practice_id).find params[:datebook_id]
    @appointment = Appointment.new
    @appointment.starts_at = params[:starts_at].to_i
    @doctors = Doctor.with_practice(current_user.practice_id).valid
  end

  def create
    @appointment = Appointment.new
    @appointment.doctor_id = params[:appointment][:doctor_id]
    @appointment.notes = params[:appointment][:notes]
    @appointment.starts_at = Time.at(params[:appointment][:starts_at].to_i)
    @appointment.datebook_id = params[:datebook_id]

    # if "as_values_patient_id" is not empty use that, otherwise use "patient_id"
    patient_id_or_name = params[:as_values_patient_id] != '' ? params[:as_values_patient_id] : (params[:appointment][:patient_id])
    @appointment.patient_id = Patient.find_or_create_from(patient_id_or_name, current_user.practice_id)

    # since the datebook_id can be freely passed, make sure its ours
    datebook_belongs_to_user = Datebook.exists?(id: params[:datebook_id], practice_id: current_user.practice_id)

    respond_to do |format|
      if datebook_belongs_to_user && @appointment.save
        format.js {} # create.js.erb
      else
        format.js do
          render_ujs_error(@appointment, I18n.t(:appointment_created_error_message))
        end
      end
    end
  end

  def show
    appointment_id_deciphered = Cipher.decode(params[:id])

    datebook = Datebook.includes(:practice).find(params[:datebook_id])
    appointment = Appointment.where(id: appointment_id_deciphered, datebook_id: datebook.id).first
  end

  def edit
    @datebook = Datebook.with_practice(current_user.practice_id).find params[:datebook_id]
    @appointment = Appointment.where(id: params[:id], datebook_id: @datebook.id).first
    @patient = Patient.with_practice(current_user.practice_id).find(params[:patient_id])
    @doctors = Doctor.with_practice(current_user.practice_id).valid
  end

  def update
    datebook = Datebook.with_practice(current_user.practice_id).find params[:datebook_id]
    @appointment = Appointment.where(id: params[:id], datebook_id: datebook.id).first

    # if "as_values_patient_id" is not empty use that, otherwise use "patient_id"
    unless params[:appointment][:patient_id].nil?
      params[:appointment][:patient_id] =
        Patient.find_or_create_from(params[:as_values_patient_id] != '' ? params[:as_values_patient_id] : (params[:appointment][:patient_id]))
    end

    respond_to do |format|
      if @appointment.update_attributes(params[:appointment])
        format.js {} # update.js.erb
      else
        format.js do
          render_ujs_error(@appointment, I18n.t(:appointment_updated_error_message))
        end
      end
    end
  end

  def destroy
    datebook = Datebook.with_practice(current_user.practice_id).find params[:datebook_id]
    @appointment = Appointment.where(id: params[:id], datebook_id: datebook.id).first

    respond_to do |format|
      if @appointment.destroy
        format.js { render action: :create } # reuses create.js.erb
      else
        format.js do
          render_ujs_error(@appointment, I18n.t(:appointment_deleted_error_message))
        end
      end
    end
  end
end
