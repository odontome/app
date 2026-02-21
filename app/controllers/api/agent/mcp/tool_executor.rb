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

        def list_appointments(args)
          datebook = resolve_datebook(args)
          starts_at = normalize_time(args["start"])
          ends_at = normalize_time(args["end"])

          appointments = if args["doctor_id"].present?
                           datebook.appointments.find_from_doctor_and_between(args["doctor_id"], starts_at, ends_at)
                         else
                           datebook.appointments.find_between(starts_at, ends_at)
                         end

          success_result(appointments.map { |a| a.as_json(agent: true) })
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
          datebook = resolve_datebook(args)
          appointment = ::Appointment.where(id: args["appointment_id"], datebook_id: datebook.id).first
          raise ActiveRecord::RecordNotFound unless appointment

          if args["doctor_id"].present?
            error = validate_doctor(args["doctor_id"])
            return error if error
          end

          attrs = {}
          attrs[:doctor_id] = args["doctor_id"] if args["doctor_id"].present?
          attrs[:notes] = args["notes"] if args.key?("notes")
          attrs[:status] = args["status"] if args["status"].present?
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
            Time.zone.parse(value.to_s)
          end
        end

        def find_patient_id(patient_id, patient_name)
          if patient_id.present?
            patient = Patient.with_practice(@practice.id).find_by(id: patient_id)
            return patient.id if patient
          end

          return Patient.find_or_create_from(patient_name, @practice.id) if patient_name.present?

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
