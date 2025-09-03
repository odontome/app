# frozen_string_literal: true

module Api::Mcp
  class AppointmentsController < BaseController
    before_action :ensure_practice_exists
    before_action :set_appointment, only: [:show, :update, :destroy]
    
    def index
      @appointments = practice_appointments.includes(:doctor, :patient)
        .order('starts_at DESC')
        .limit(100)
      
      render_success(@appointments.as_json(include: [:doctor, :patient]))
    end
    
    def show
      render_success(@appointment.as_json(include: [:doctor, :patient]))
    end
    
    def create
      # Validate that datebook belongs to current practice
      datebook = Datebook.with_practice(current_user.practice_id).find_by(id: appointment_params[:datebook_id])
      unless datebook
        render json: { error: 'Datebook not found or not accessible' }, status: :not_found
        return
      end
      
      # Validate that doctor belongs to current practice
      if appointment_params[:doctor_id] && !Doctor.with_practice(current_user.practice_id).exists?(id: appointment_params[:doctor_id])
        render json: { error: 'Doctor not found or not accessible' }, status: :not_found
        return
      end
      
      # Validate that patient belongs to current practice
      if appointment_params[:patient_id] && !Patient.with_practice(current_user.practice_id).exists?(id: appointment_params[:patient_id])
        render json: { error: 'Patient not found or not accessible' }, status: :not_found
        return
      end
      
      @appointment = Appointment.new(appointment_params)
      
      if @appointment.save
        render_success(@appointment.as_json(include: [:doctor, :patient]), status: :created)
      else
        render_validation_errors(@appointment)
      end
    end
    
    def update
      if @appointment.update(appointment_params)
        render_success(@appointment.as_json(include: [:doctor, :patient]))
      else
        render_validation_errors(@appointment)
      end
    end
    
    def destroy
      @appointment.destroy
      head :no_content
    end
    
    private
    
    def practice_appointments
      # Get appointments through datebooks that belong to the current practice
      Appointment.joins(:datebook)
        .where(datebooks: { practice_id: current_user.practice_id })
    end
    
    def set_appointment
      @appointment = practice_appointments.find_by(id: params[:id])
      
      unless @appointment
        render_not_found('Appointment not found')
        return false
      end
    end
    
    def appointment_params
      params.require(:appointment).permit(
        :datebook_id, :doctor_id, :patient_id, :starts_at, :ends_at, 
        :notes, :status
      )
    end
  end
end