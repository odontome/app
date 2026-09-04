# frozen_string_literal: true

class AppointmentsController < ApplicationController
  before_action :require_user
  rescue_from ActiveRecord::RecordNotFound, with: :appointment_not_found

  layout false, except: :show

  def index
    datebook = Datebook.with_practice(current_user.practice_id).find(params[:datebook_id])

    starts_at = calendar_time(params[:start])
    ends_at = calendar_time(params[:end])
    unless starts_at && ends_at && starts_at < ends_at
      respond_to do |format|
        format.html { @appointments = Appointment.none }
        format.json { render json: [] }
      end
      return
    end

    ends_at = [ends_at, starts_at + 90.days].min
    @appointments = datebook.appointments.overlapping(starts_at, ends_at)
                            .includes(:doctor, :patient, datebook: :practice).order(:starts_at)
    @appointments = @appointments.where(doctor_id: params[:doctor_id]) if params[:doctor_id].present?

    respond_to do |format|
      format.html
      format.json do
        wall_clock = params[:wall_clock] == '1'
        render json: @appointments.map { |appointment| appointment.as_json(wall_clock: wall_clock) }
      end
    end
  end

  def new
    @datebook = Datebook.with_practice(current_user.practice_id).find params[:datebook_id]
    @appointment = Appointment.new
    @appointment.starts_at = calendar_time(params[:starts_at])
    @doctors = Doctor.with_practice(current_user.practice_id).valid
  end

  def create
    @appointment = Appointment.new
    @appointment.doctor_id = params[:appointment][:doctor_id]
    @appointment.notes = params[:appointment][:notes]
    @appointment.starts_at = calendar_time(params[:appointment][:starts_at])
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
    attributes = params.require(:appointment).permit(:datebook_id, :doctor_id, :patient_id, :starts_at, :ends_at, :notes, :status)
    %i[starts_at ends_at].each do |key|
      attributes[key] = calendar_time(attributes[key]) if attributes.key?(key)
    end
    attributes
  end

  # Calendar clicks and moves send practice wall time, not a browser-local epoch.
  # Keep accepting Unix timestamps and offset-bearing strings from existing clients.
  def calendar_time(value)
    return if value.blank?

    value.to_s.match?(/\A\d+\z/) ? Time.at(value.to_i) : Time.zone.parse(value.to_s)
  rescue ArgumentError, TypeError
    nil
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
