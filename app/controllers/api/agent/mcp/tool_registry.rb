# frozen_string_literal: true

module Api
  module Agent
    module Mcp
      module ToolRegistry
        TOOLS = [
          {
            name: "list_datebooks",
            description: "List all datebooks (appointment calendars) for the dental practice. Each datebook typically represents a clinic location.",
            inputSchema: {
              type: "object",
              properties: {},
              required: []
            }
          },
          {
            name: "list_doctors",
            description: "List all active dentists and specialists for the practice. Returns their name, specialty, and ID needed for scheduling.",
            inputSchema: {
              type: "object",
              properties: {},
              required: []
            }
          },
          {
            name: "list_appointments",
            description: "Query the schedule for a date range. Use this to check availability, see who is coming in today, or review upcoming appointments. Optionally filter by doctor.",
            inputSchema: {
              type: "object",
              properties: {
                datebook_id: { type: "integer", description: "Datebook ID" },
                datebook_name: { type: "string", description: "Datebook name (alternative to datebook_id)" },
                start: { type: "string", description: "Range start (ISO 8601 or Unix timestamp)" },
                end: { type: "string", description: "Range end (ISO 8601 or Unix timestamp)" },
                doctor_id: { type: "integer", description: "Filter by a specific doctor's schedule (optional)" }
              },
              required: %w[start end]
            }
          },
          {
            name: "create_appointment",
            description: "Book a new patient appointment. Requires a doctor and time slot. You can reference an existing patient by ID or create a new patient record by providing their name. Times must fall within the datebook's working hours.",
            inputSchema: {
              type: "object",
              properties: {
                datebook_id: { type: "integer", description: "Datebook ID" },
                datebook_name: { type: "string", description: "Datebook name (alternative to datebook_id)" },
                doctor_id: { type: "integer", description: "Doctor who will see the patient" },
                patient_id: { type: "integer", description: "Existing patient ID (use search_patients to find). Optional if patient_name is given." },
                patient_name: { type: "string", description: "Full name for a new patient (a record will be created automatically). Optional if patient_id is given." },
                starts_at: { type: "string", description: "Appointment start time (ISO 8601 or Unix timestamp)" },
                ends_at: { type: "string", description: "Appointment end time (ISO 8601 or Unix timestamp)" },
                notes: { type: "string", description: "Reason for visit or clinical notes, e.g. 'Routine cleaning', 'Crown prep', 'Emergency toothache' (max 255 chars)" }
              },
              required: %w[doctor_id starts_at ends_at]
            }
          },
          {
            name: "update_appointment",
            description: "Modify an existing appointment. Use this to reschedule (change time), reassign to a different doctor, update notes, cancel, or confirm. To cancel an appointment set status to 'cancelled'. To confirm set status to 'confirmed'.",
            inputSchema: {
              type: "object",
              properties: {
                datebook_id: { type: "integer", description: "Datebook ID" },
                datebook_name: { type: "string", description: "Datebook name (alternative to datebook_id)" },
                appointment_id: { type: "integer", description: "Appointment ID to update" },
                doctor_id: { type: "integer", description: "Reassign to a different doctor (optional)" },
                starts_at: { type: "string", description: "New start time for rescheduling (optional)" },
                ends_at: { type: "string", description: "New end time for rescheduling (optional)" },
                notes: { type: "string", description: "Updated reason for visit or clinical notes (optional)" },
                status: { type: "string", enum: %w[confirmed cancelled], description: "Set to 'cancelled' to cancel or 'confirmed' to confirm the appointment (optional)" }
              },
              required: %w[appointment_id]
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
            }
          }
        ].freeze

        def self.definitions
          TOOLS
        end
      end
    end
  end
end
