# frozen_string_literal: true

module Api
  module Agent
    module Mcp
      class ToolExecutor
        def initialize(practice)
          @practice = practice
        end

        def call(tool_name, arguments)
          case tool_name
          when "list_datebooks"   then list_datebooks
          when "list_doctors"     then list_doctors
          when "list_appointments" then list_appointments(arguments)
          when "create_appointment" then create_appointment(arguments)
          when "update_appointment" then update_appointment(arguments)
          when "search_patients"  then search_patients(arguments)
          else
            error_result(I18n.t("agents.mcp.errors.unknown_tool", tool: tool_name))
          end
        rescue ActiveRecord::RecordNotFound
          error_result(I18n.t("agents.mcp.errors.record_not_found"))
        end

        private

        def list_datebooks
          datebooks = Datebook.with_practice(@practice.id).map { |d| { id: d.id, name: d.name } }
          success_result(datebooks)
        end

        def list_doctors
          doctors = Doctor.with_practice(@practice.id).valid.map do |d|
            { id: d.id, uid: d.uid, name: d.fullname, speciality: d.speciality }
          end
          success_result(doctors)
        end

        MAX_DATE_RANGE_DAYS = 90
        MAX_RESULTS = 500

        def list_appointments(args)
          datebook = resolve_datebook(args)
          starts_at = normalize_time(args["start"])
          ends_at = normalize_time(args["end"])

          return error_result(I18n.t("agents.mcp.errors.invalid_date_range")) if starts_at >= ends_at

          if (ends_at - starts_at) > MAX_DATE_RANGE_DAYS.days
            return error_result(I18n.t("agents.mcp.errors.date_range_too_wide", max: MAX_DATE_RANGE_DAYS))
          end

          appointments = if args["doctor_id"].present?
                           datebook.appointments.find_from_doctor_and_between(args["doctor_id"], starts_at, ends_at)
                         else
                           datebook.appointments.find_between(starts_at, ends_at)
                         end

          success_result(appointments.limit(MAX_RESULTS).map { |a| a.as_json(agent: true) })
        end

        def create_appointment(args)
          datebook = resolve_datebook(args)

          error = validate_doctor(args["doctor_id"])
          return error if error

          appointment = ::Appointment.new(
            datebook_id: datebook.id,
            doctor_id: args["doctor_id"],
            notes: args["notes"]
          )

          appointment.starts_at = normalize_time(args["starts_at"]) if args["starts_at"].present?
          appointment.ends_at = normalize_time(args["ends_at"]) if args["ends_at"].present?
          appointment.patient_id = find_patient_id(args["patient_id"], args["patient_name"])

          error = validate_working_hours(datebook, appointment)
          return error if error

          if appointment.save
            success_result(appointment.as_json(agent: true))
          else
            error_result(appointment.errors.full_messages.join(", "))
          end
        end

        def update_appointment(args)
          appointment = find_practice_appointment(args["appointment_id"])
          raise ActiveRecord::RecordNotFound unless appointment
          datebook = appointment.datebook

          if args["doctor_id"].present?
            error = validate_doctor(args["doctor_id"])
            return error if error
          end

          attrs = {}
          attrs[:doctor_id] = args["doctor_id"] if args["doctor_id"].present?
          attrs[:notes] = args["notes"] if args.key?("notes")

          if args["status"].present?
            unless ALLOWED_STATUSES.include?(args["status"])
              return error_result("Invalid status. Allowed values: #{ALLOWED_STATUSES.join(', ')}")
            end
            attrs[:status] = args["status"]
          end
          appointment.assign_attributes(attrs) if attrs.any?

          appointment.starts_at = normalize_time(args["starts_at"]) if args["starts_at"].present?
          appointment.ends_at = normalize_time(args["ends_at"]) if args["ends_at"].present?

          error = validate_working_hours(datebook, appointment)
          return error if error

          if appointment.save
            success_result(appointment.as_json(agent: true))
          else
            error_result(appointment.errors.full_messages.join(", "))
          end
        end

        def search_patients(args)
          patients = Patient.with_practice(@practice.id).search(args["query"]).map do |p|
            { id: p.id, uid: p.uid, firstname: p.firstname, lastname: p.lastname }
          end
          success_result(patients)
        end

        def validate_doctor(doctor_id)
          doctor = Doctor.with_practice(@practice.id).find_by(id: doctor_id)

          if doctor.nil?
            return error_result("Doctor not found in this practice")
          end

          unless doctor.is_active?
            return error_result("Doctor #{doctor.fullname} is currently inactive")
          end

          nil
        end

        def validate_working_hours(datebook, appointment)
          tz = datebook.practice.timezone
          start_hour = appointment.starts_at.in_time_zone(tz).hour
          end_hour = appointment.ends_at.in_time_zone(tz).hour

          return if start_hour >= datebook.starts_at && end_hour <= datebook.ends_at

          error_result(
            "Appointment must be within working hours (#{datebook.starts_at}:00 - #{datebook.ends_at}:00)"
          )
        end

        # --- helpers (same patterns as AppointmentsController) ---

        def find_practice_appointment(appointment_id)
          ::Appointment.joins(:datebook)
                       .where(datebooks: { practice_id: @practice.id })
                       .where(id: appointment_id)
                       .first
        end

        def resolve_datebook(args)
          scope = Datebook.with_practice(@practice.id)

          if args["datebook_name"].present?
            return scope.find_by!(name: args["datebook_name"])
          end

          raw_id = args["datebook_id"].to_s
          raise ActiveRecord::RecordNotFound unless raw_id.match?(/\A\d+\z/)

          scope.find(raw_id)
        end

        def normalize_time(value)
          return if value.blank?

          if value.to_s.match?(/\A\d+\z/)
            Time.at(value.to_i)
          else
            # Strip any timezone offset so the time is always interpreted
            # as the practice's local time. The MCP instructions tell agents
            # to send times in the practice timezone, but some send UTC.
            naive = value.to_s.sub(/[Zz]$/, "").sub(/[+-]\d{2}:\d{2}$/, "")
            practice_tz.parse(naive)
          end
        end

        def practice_tz
          ActiveSupport::TimeZone[@practice.timezone]
        end

        ALLOWED_STATUSES = %w[confirmed cancelled].freeze

        def find_patient_id(patient_id, patient_name)
          if patient_id.present?
            patient = Patient.with_practice(@practice.id).find_by(id: patient_id)
            return patient.id if patient
          end

          if patient_name.present?
            result_id = Patient.find_or_create_from(patient_name, @practice.id)
            # Verify the patient belongs to this practice. find_or_create_from
            # treats numeric strings as patient ID lookups without practice
            # scoping, which could link to a patient from another practice.
            return result_id if result_id && Patient.with_practice(@practice.id).where(id: result_id).exists?
          end

          nil
        end

        def success_result(data)
          { content: [{ type: "text", text: data.to_json }], isError: false }
        end

        def error_result(message)
          { content: [{ type: "text", text: message }], isError: true }
        end
      end
    end
  end
end
