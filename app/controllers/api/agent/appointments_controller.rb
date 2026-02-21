# frozen_string_literal: true

module Api
  module Agent
    class AppointmentsController < BaseController
      def index
        datebook = resolve_datebook
        starts_at, ends_at = normalize_range_params
        appointments = if params[:doctor_id]
                         datebook.appointments.find_from_doctor_and_between(params[:doctor_id], starts_at, ends_at)
                       else
                         datebook.appointments.find_between(starts_at, ends_at)
                       end

        render json: appointments.map { |appointment| appointment.as_json(agent: true) }
      end

      def create
        datebook = resolve_datebook
        appointment = Appointment.new(appointment_params)
        appointment.datebook_id = datebook.id
        apply_time_params(appointment)

        patient_id = params.dig(:appointment, :patient_id)
        patient_name = params.dig(:appointment, :patient_name)

        appointment.patient_id = find_patient_id(patient_id, patient_name)

        if appointment.save
          render json: appointment.as_json(agent: true), status: :created
        else
          render json: { errors: appointment.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        datebook = resolve_datebook
        appointment = Appointment.where(id: params[:id], datebook_id: datebook.id).first

        unless appointment
          render json: { error: I18n.t('agents.errors.not_found') }, status: :not_found
          return
        end

        if appointment.update(appointment_update_params)
          apply_time_params(appointment)
          appointment.save if appointment.changed?
          render json: appointment.as_json(agent: true)
        else
          render json: { errors: appointment.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def appointment_params
        params.require(:appointment).permit(:doctor_id, :starts_at, :ends_at, :notes)
      end

      def appointment_update_params
        params.require(:appointment).permit(:doctor_id, :starts_at, :ends_at, :notes)
      end

      def resolve_datebook
        raw_id = params[:datebook_id].to_s
        datebook_name = params[:datebook_name].presence
        scope = Datebook.with_practice(@practice.id)

        return scope.find_by!(name: datebook_name) if datebook_name.present?

        raise ActiveRecord::RecordNotFound unless raw_id.match?(/\A\d+\z/)

        scope.find(raw_id)
      end

      def normalize_range_params
        starts_at = normalize_time_param(params[:start])
        ends_at = normalize_time_param(params[:end])

        [starts_at, ends_at]
      end

      def find_patient_id(patient_id, patient_name)
        if patient_id.present?
          patient = Patient.with_practice(@practice.id).find_by(id: patient_id)
          return patient.id if patient
        end

        return Patient.find_or_create_from(patient_name, @practice.id) if patient_name.present?

        nil
      end

      def apply_time_params(appointment)
        starts_at = normalize_time_param(params.dig(:appointment, :starts_at))
        ends_at = normalize_time_param(params.dig(:appointment, :ends_at))

        appointment.starts_at = starts_at if starts_at.present?
        appointment.ends_at = ends_at if ends_at.present?
      end

      def normalize_time_param(value)
        return if value.blank?

        if value.to_s.match?(/\A\d+\z/)
          Time.at(value.to_i)
        else
          Time.zone.parse(value.to_s)
        end
      end
    end
  end
end
