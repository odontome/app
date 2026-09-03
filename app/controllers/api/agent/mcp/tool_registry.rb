# frozen_string_literal: true

module Api
  module Agent
    module Mcp
      module ToolRegistry
        DATEBOOK_SCHEMA = {
          type: "object",
          properties: {
            id: { type: "integer" },
            name: { type: "string" },
            timezone: { type: "string", description: "IANA practice timezone; use its offset for the appointment date." },
            working_hours: {
              type: "object",
              description: "Daily opening and closing times in the practice timezone. The full appointment must fit within this range on one day.",
              properties: {
                start: { type: "string", pattern: "^([01][0-9]|2[0-3]):[0-5][0-9]$" },
                end: { type: "string", pattern: "^([01][0-9]|2[0-3]):[0-5][0-9]$" }
              },
              required: %w[start end],
              additionalProperties: false
            }
          },
          required: %w[id name timezone working_hours],
          additionalProperties: false
        }.freeze

        DOCTOR_SCHEMA = {
          type: "object",
          properties: {
            id: { type: "integer" },
            uid: { type: %w[string null] },
            name: { type: "string" },
            speciality: { type: %w[string null] }
          },
          required: %w[id uid name speciality],
          additionalProperties: false
        }.freeze

        APPOINTMENT_SCHEMA = {
          type: "object",
          properties: {
            id: { type: "integer" },
            start: { type: "string", format: "date-time" },
            end: { type: "string", format: "date-time" },
            doctor_id: { type: "integer" },
            doctor_name: { type: "string" },
            datebook_id: { type: "integer" },
            datebook_name: { type: "string" },
            patient_id: { type: "integer" },
            patient_name: { type: "string" },
            status: { type: "string" }
          },
          required: %w[id start end doctor_id doctor_name datebook_id datebook_name patient_id patient_name status],
          additionalProperties: false
        }.freeze

        PATIENT_SCHEMA = {
          type: "object",
          properties: {
            id: { type: "integer" },
            uid: { type: %w[string null] },
            firstname: { type: "string" },
            lastname: { type: "string" }
          },
          required: %w[id uid firstname lastname],
          additionalProperties: false
        }.freeze

        OUTPUT_SCHEMAS = {
          "list_datebooks" => {
            type: "object",
            properties: { datebooks: { type: "array", items: DATEBOOK_SCHEMA } },
            required: %w[datebooks],
            additionalProperties: false
          },
          "list_doctors" => {
            type: "object",
            properties: { doctors: { type: "array", items: DOCTOR_SCHEMA } },
            required: %w[doctors],
            additionalProperties: false
          },
          "list_appointments" => {
            type: "object",
            properties: { appointments: { type: "array", items: APPOINTMENT_SCHEMA } },
            required: %w[appointments],
            additionalProperties: false
          },
          "create_appointment" => {
            type: "object",
            properties: { appointment: APPOINTMENT_SCHEMA },
            required: %w[appointment],
            additionalProperties: false
          },
          "update_appointment" => {
            type: "object",
            properties: { appointment: APPOINTMENT_SCHEMA },
            required: %w[appointment],
            additionalProperties: false
          },
          "search_patients" => {
            type: "object",
            properties: { patients: { type: "array", items: PATIENT_SCHEMA } },
            required: %w[patients],
            additionalProperties: false
          }
        }.freeze

        TOOLS = [
          {
            name: "list_datebooks",
            description: "List practice calendars with their IANA timezone and daily working_hours (start/end in HH:MM). Read these before proposing a booking or reschedule; an empty schedule does not mean the calendar is open all day.",
            inputSchema: {
              type: "object",
              properties: {},
              required: []
            },
            annotations: {
              title: "List datebooks",
              readOnlyHint: true,
              destructiveHint: false,
              idempotentHint: true,
              openWorldHint: false
            }
          },
          {
            name: "list_doctors",
            description: "List all active dentists and specialists for the practice. Returns their name, specialty, and ID needed for scheduling.",
            inputSchema: {
              type: "object",
              properties: {},
              required: []
            },
            annotations: {
              title: "List doctors",
              readOnlyHint: true,
              destructiveHint: false,
              idempotentHint: true,
              openWorldHint: false
            }
          },
          {
            name: "list_appointments",
            description: "Query appointments that overlap a date range in one calendar. Requires datebook_id or datebook_name. If the calendar is unknown, call list_datebooks first; for a practice-wide schedule, query each returned calendar separately. Use this to check a selected doctor's availability before creating or rescheduling, see who is coming in today, or review upcoming appointments.",
            inputSchema: {
              type: "object",
              properties: {
                datebook_id: { type: "integer", description: "Datebook ID" },
                datebook_name: { type: "string", description: "Datebook name (alternative to datebook_id)" },
                start: { type: "string", description: "Range start — ISO 8601 in the practice's timezone (e.g. '2026-02-21T08:00:00-05:00')" },
                end: { type: "string", description: "Range end — ISO 8601 in the practice's timezone" },
                doctor_id: { type: "integer", description: "Filter by a specific doctor's schedule (optional)" }
              },
              required: %w[start end],
              anyOf: [
                { required: %w[datebook_id] },
                { required: %w[datebook_name] }
              ]
            },
            annotations: {
              title: "List appointments",
              readOnlyHint: true,
              destructiveHint: false,
              idempotentHint: true,
              openWorldHint: false
            }
          },
          {
            name: "create_appointment",
            description: "Book a new patient appointment after the user explicitly confirms the exact doctor, patient, datebook, and time. Requires datebook_id or datebook_name; call list_datebooks first if the calendar is unknown. First search for an existing patient and check the selected doctor's availability. A new patient record is created only when patient_name is provided. Times must fall within working hours, and overlapping appointments for the same doctor in the selected datebook are rejected.",
            inputSchema: {
              type: "object",
              properties: {
                datebook_id: { type: "integer", description: "Datebook ID" },
                datebook_name: { type: "string", description: "Datebook name (alternative to datebook_id)" },
                doctor_id: { type: "integer", description: "Doctor who will see the patient" },
                patient_id: { type: "integer", description: "Existing patient ID (use search_patients to find). Optional if patient_name is given." },
                patient_name: { type: "string", description: "Full name for a new patient (a record will be created automatically). Optional if patient_id is given." },
                starts_at: { type: "string", description: "Appointment start time — ISO 8601 in the practice's timezone (e.g. '2026-02-21T15:00:00-05:00')" },
                ends_at: { type: "string", description: "Appointment end time — ISO 8601 in the practice's timezone" }
              },
              required: %w[doctor_id starts_at ends_at],
              anyOf: [
                { required: %w[datebook_id] },
                { required: %w[datebook_name] }
              ]
            },
            annotations: {
              title: "Create appointment",
              readOnlyHint: false,
              destructiveHint: false,
              idempotentHint: false,
              openWorldHint: false
            }
          },
          {
            name: "update_appointment",
            description: "Modify an existing appointment after the user explicitly confirms the exact change. Use this to reschedule, reassign to a different doctor, cancel, or confirm. Check the selected doctor's availability before rescheduling or reassigning. To cancel set status to 'cancelled'; to confirm set status to 'confirmed'. Overlapping appointments for the same doctor in the datebook are rejected.",
            inputSchema: {
              type: "object",
              properties: {
                appointment_id: { type: "integer", description: "Appointment ID to update" },
                doctor_id: { type: "integer", description: "Reassign to a different doctor (optional)" },
                starts_at: { type: "string", description: "New start time — ISO 8601 in the practice's timezone (optional)" },
                ends_at: { type: "string", description: "New end time — ISO 8601 in the practice's timezone (optional)" },
                status: { type: "string", enum: %w[confirmed cancelled], description: "Set to 'cancelled' to cancel or 'confirmed' to confirm the appointment (optional)" }
              },
              required: %w[appointment_id]
            },
            annotations: {
              title: "Update appointment",
              readOnlyHint: false,
              destructiveHint: true,
              idempotentHint: true,
              openWorldHint: false
            }
          },
          {
            name: "search_patients",
            description: "Search the patient directory by name or patient ID number (UID). Use this to find a patient before booking an appointment.",
            inputSchema: {
              type: "object",
              properties: {
                query: { type: "string", description: "Patient name or UID to search for" }
              },
              required: %w[query]
            },
            annotations: {
              title: "Search patients",
              readOnlyHint: true,
              destructiveHint: false,
              idempotentHint: true,
              openWorldHint: false
            }
          }
        ].freeze

        def self.definitions
          TOOLS.map do |tool|
            tool.merge(
              outputSchema: OUTPUT_SCHEMAS.fetch(tool[:name]),
              securitySchemes: [{ type: "oauth2", scopes: [] }]
            )
          end
        end
      end
    end
  end
end
