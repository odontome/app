# frozen_string_literal: true

class AppointmentsController < ApplicationController
  before_action :require_user
  rescue_from ActiveRecord::RecordNotFound, with: :appointment_not_found

  layout false, except: :show

  def index
    datebook = Datebook.with_practice(current_user.practice_id).find(params[:datebook_id])

    unless params[:start].present? && params[:end].present?
      respond_to do |format|
        format.html { @appointments = Appointment.none }
        format.json { render json: [] }
      end
      return
    end

    start_ts = params[:start].to_i
    end_ts   = params[:end].to_i
    max_window = 90.days.to_i
    end_ts = start_ts + max_window if (end_ts - start_ts) > max_window

    @appointments = if params[:doctor_id]
                      datebook.appointments.find_from_doctor_and_between(params[:doctor_id], start_ts,
                                                                         end_ts)
                    else
                      datebook.appointments.find_between(start_ts, end_ts)
                    end

    respond_to do |format|
      format.html
      format.json { render json: @appointments }
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

    patient_id_or_name = params[:appointment][:patient_id].blank? ? params[:as_values_patient_id] : params[:appointment][:patient_id]
    @appointment.patient_id = Patient.find_or_create_from(patient_id_or_name, current_user.practice_id)

    # since the datebook_id can be freely passed, make sure its ours
    datebook_belongs_to_user = Datebook.exists?(id: params[:datebook_id], practice_id: current_user.practice_id)

    respond_to do |format|
      if datebook_belongs_to_user && @appointment.save
        format.js {}
      else
        format.js do
          render_ujs_error(@appointment, I18n.t(:appointment_created_error_message))
        end
      end
    end
  end

  def show
    datebook = Datebook.with_practice(current_user.practice_id).find(params[:datebook_id])
    @appointment = Appointment.includes(%i[doctor patient]).find_by!(id: params[:id], datebook_id: datebook.id)
  end

  def edit
    @datebook = Datebook.with_practice(current_user.practice_id).find params[:datebook_id]
    @appointment = Appointment.find_by!(id: params[:id], datebook_id: @datebook.id)
    @patient = Patient.with_practice(current_user.practice_id).find(params[:patient_id])
    @doctors = Doctor.with_practice(current_user.practice_id).valid
  end

  def update
    datebook = Datebook.with_practice(current_user.practice_id).find params[:datebook_id]
    @appointment = Appointment.find_by!(id: params[:id], datebook_id: datebook.id)

    # if there is no `as_values_patient_id` the appointment is just getting moved
    # otherwise, clean up the fields
    if params[:appointment][:patient_id].blank? && params[:as_values_patient_id].present?
      params[:appointment][:patient_id] =
        Patient.find_or_create_from(params[:as_values_patient_id], current_user.practice_id)
    end

    respond_to do |format|
      if @appointment.update(appointment_params)
        format.js {}
        format.html do
          redirect_back fallback_location: practice_appointments_url,
                        notice: I18n.t(:appointment_updated_success_message)
        end
      else
        format.js do
          render_ujs_error(@appointment, I18n.t(:appointment_updated_error_message))
        end
        format.html do
          redirect_back fallback_location: practice_appointments_url,
                        alert: I18n.t(:appointment_updated_error_message)
        end
      end
    end
  end

  def destroy
    datebook = Datebook.with_practice(current_user.practice_id).find params[:datebook_id]
    @appointment = Appointment.find_by!(id: params[:id], datebook_id: datebook.id)

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

  private

  def appointment_params
    params.require(:appointment).permit(:datebook_id, :doctor_id, :patient_id, :starts_at, :ends_at, :notes, :status)
  end

  def appointment_not_found
    message = I18n.t(:appointment_not_found_message)
    respond_to do |format|
      format.html { render inline: "<script>alert('#{helpers.sanitize(message)}');</script>", layout: false }
      format.json { render json: { error: "Not found" }, status: :not_found }
      format.js   { render js: "alert('#{helpers.sanitize(message)}');" }
    end
  end
end
