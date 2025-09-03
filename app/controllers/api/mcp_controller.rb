# frozen_string_literal: true

module Api
  # Model Context Protocol (MCP) Server Implementation
  # 
  # This controller implements the Model Context Protocol standard for AI model integration.
  # It provides JSON-RPC 2.0 style messaging with tool discovery and standardized error handling.
  #
  # MCP Endpoints:
  # - GET /api/mcp/capabilities - Discover available tools and resources
  # - POST /api/mcp - Handle JSON-RPC 2.0 requests with method names
  #
  # Supported Methods:
  # - appointments/list - List appointments with doctor/patient details
  # - appointments/get - Get specific appointment by ID
  # - appointments/create - Create new appointment
  # - appointments/update - Update existing appointment
  # - appointments/delete - Delete appointment
  # - datebooks/list - List datebooks with appointments
  # - datebooks/get - Get specific datebook by ID
  # - datebooks/create - Create new datebook
  # - datebooks/update - Update existing datebook
  # - datebooks/delete - Delete datebook (only if no appointments)
  class McpController < ApplicationController
    # Skip CSRF protection for MCP API endpoints
    skip_forgery_protection
    
    # Require user authentication for all MCP endpoints
    before_action :require_user
    
    # JSON responses only
    respond_to :json
    
    # MCP capabilities discovery endpoint
    def capabilities
      render json: {
        capabilities: {
          tools: mcp_tools,
          resources: mcp_resources
        },
        serverInfo: {
          name: 'Odontome MCP Server',
          version: '1.0.0',
          description: 'Model Context Protocol server for Odontome dental practice management'
        },
        protocolVersion: '2024-11-05'
      }
    end
    
    # Main MCP request handler using JSON-RPC 2.0
    def handle_request
      begin
        # Parse JSON-RPC request
        request_data = JSON.parse(request.body.read)
        
        # Validate JSON-RPC format
        unless request_data['jsonrpc'] == '2.0' && request_data['method']
          return render_error(-32600, 'Invalid Request', request_data['id'])
        end
        
        method_name = request_data['method']
        params = request_data['params'] || {}
        request_id = request_data['id']
        
        # Route to appropriate handler
        result = case method_name
                when 'appointments/list'
                  handle_appointments_list(params)
                when 'appointments/get'
                  handle_appointments_get(params)
                when 'appointments/create'
                  handle_appointments_create(params)
                when 'appointments/update'
                  handle_appointments_update(params)
                when 'appointments/delete'
                  handle_appointments_delete(params)
                when 'datebooks/list'
                  handle_datebooks_list(params)
                when 'datebooks/get'
                  handle_datebooks_get(params)
                when 'datebooks/create'
                  handle_datebooks_create(params)
                when 'datebooks/update'
                  handle_datebooks_update(params)
                when 'datebooks/delete'
                  handle_datebooks_delete(params)
                else
                  return render_error(-32601, 'Method not found', request_id)
                end
        
        # Return successful JSON-RPC response
        render json: {
          jsonrpc: '2.0',
          result: result,
          id: request_id
        }
        
      rescue JSON::ParserError
        render_error(-32700, 'Parse error', nil)
      rescue => e
        Rails.logger.error "MCP Error: #{e.message}"
        render_error(-32603, 'Internal error', request_data&.dig('id'))
      end
    end
    
    private
    
    # MCP tool definitions for AI models
    def mcp_tools
      [
        {
          name: 'appointments/list',
          description: 'List appointments with doctor and patient information',
          inputSchema: {
            type: 'object',
            properties: {
              limit: { type: 'integer', description: 'Maximum number of appointments to return (default 100)' },
              doctor_id: { type: 'integer', description: 'Filter by doctor ID' },
              patient_id: { type: 'integer', description: 'Filter by patient ID' },
              start_date: { type: 'string', format: 'date-time', description: 'Filter appointments after this date' },
              end_date: { type: 'string', format: 'date-time', description: 'Filter appointments before this date' }
            }
          }
        },
        {
          name: 'appointments/get',
          description: 'Get specific appointment by ID',
          inputSchema: {
            type: 'object',
            properties: {
              id: { type: 'integer', description: 'Appointment ID' }
            },
            required: ['id']
          }
        },
        {
          name: 'appointments/create',
          description: 'Create new appointment',
          inputSchema: {
            type: 'object',
            properties: {
              datebook_id: { type: 'integer', description: 'Datebook ID' },
              doctor_id: { type: 'integer', description: 'Doctor ID' },
              patient_id: { type: 'integer', description: 'Patient ID' },
              starts_at: { type: 'string', format: 'date-time', description: 'Appointment start time' },
              ends_at: { type: 'string', format: 'date-time', description: 'Appointment end time' },
              notes: { type: 'string', description: 'Appointment notes' },
              status: { type: 'string', description: 'Appointment status' }
            },
            required: ['datebook_id', 'starts_at']
          }
        },
        {
          name: 'appointments/update',
          description: 'Update existing appointment',
          inputSchema: {
            type: 'object',
            properties: {
              id: { type: 'integer', description: 'Appointment ID' },
              datebook_id: { type: 'integer', description: 'Datebook ID' },
              doctor_id: { type: 'integer', description: 'Doctor ID' },
              patient_id: { type: 'integer', description: 'Patient ID' },
              starts_at: { type: 'string', format: 'date-time', description: 'Appointment start time' },
              ends_at: { type: 'string', format: 'date-time', description: 'Appointment end time' },
              notes: { type: 'string', description: 'Appointment notes' },
              status: { type: 'string', description: 'Appointment status' }
            },
            required: ['id']
          }
        },
        {
          name: 'appointments/delete',
          description: 'Delete appointment',
          inputSchema: {
            type: 'object',
            properties: {
              id: { type: 'integer', description: 'Appointment ID' }
            },
            required: ['id']
          }
        },
        {
          name: 'datebooks/list',
          description: 'List datebooks with appointments',
          inputSchema: {
            type: 'object',
            properties: {
              include_appointments: { type: 'boolean', description: 'Include appointments in response (default true)' }
            }
          }
        },
        {
          name: 'datebooks/get',
          description: 'Get specific datebook by ID',
          inputSchema: {
            type: 'object',
            properties: {
              id: { type: 'integer', description: 'Datebook ID' },
              include_appointments: { type: 'boolean', description: 'Include appointments in response (default true)' }
            },
            required: ['id']
          }
        },
        {
          name: 'datebooks/create',
          description: 'Create new datebook',
          inputSchema: {
            type: 'object',
            properties: {
              name: { type: 'string', description: 'Datebook name' },
              starts_at: { type: 'string', format: 'time', description: 'Start time' },
              ends_at: { type: 'string', format: 'time', description: 'End time' }
            },
            required: ['name']
          }
        },
        {
          name: 'datebooks/update',
          description: 'Update existing datebook',
          inputSchema: {
            type: 'object',
            properties: {
              id: { type: 'integer', description: 'Datebook ID' },
              name: { type: 'string', description: 'Datebook name' },
              starts_at: { type: 'string', format: 'time', description: 'Start time' },
              ends_at: { type: 'string', format: 'time', description: 'End time' }
            },
            required: ['id']
          }
        },
        {
          name: 'datebooks/delete',
          description: 'Delete datebook (only if no appointments)',
          inputSchema: {
            type: 'object',
            properties: {
              id: { type: 'integer', description: 'Datebook ID' }
            },
            required: ['id']
          }
        }
      ]
    end
    
    # MCP resource definitions
    def mcp_resources
      [
        {
          uri: 'odontome://appointments',
          name: 'Appointments',
          description: 'Dental practice appointments with doctor and patient information',
          mimeType: 'application/json'
        },
        {
          uri: 'odontome://datebooks',
          name: 'Datebooks',
          description: 'Appointment scheduling datebooks for dental practice',
          mimeType: 'application/json'
        }
      ]
    end
    
    # Appointment handlers
    def handle_appointments_list(params)
      ensure_practice_exists!
      
      appointments = practice_appointments.includes(:doctor, :patient)
      
      # Apply filters
      appointments = appointments.where(doctor_id: params['doctor_id']) if params['doctor_id']
      appointments = appointments.where(patient_id: params['patient_id']) if params['patient_id']
      appointments = appointments.where('starts_at >= ?', params['start_date']) if params['start_date']
      appointments = appointments.where('starts_at <= ?', params['end_date']) if params['end_date']
      
      # Apply limit and ordering
      limit = [params['limit'].to_i, 100].min
      limit = 100 if limit <= 0
      appointments = appointments.order('starts_at DESC').limit(limit)
      
      appointments.as_json(include: [:doctor, :patient])
    end
    
    def handle_appointments_get(params)
      ensure_practice_exists!
      
      appointment = practice_appointments.find_by(id: params['id'])
      raise_not_found('Appointment not found') unless appointment
      
      appointment.as_json(include: [:doctor, :patient])
    end
    
    def handle_appointments_create(params)
      ensure_practice_exists!
      
      # Validate datebook belongs to current practice
      datebook = practice_datebooks.find_by(id: params['datebook_id'])
      raise_not_found('Datebook not found or not accessible') unless datebook
      
      # Validate doctor belongs to current practice if provided
      if params['doctor_id']
        doctor = practice_doctors.find_by(id: params['doctor_id'])
        raise_not_found('Doctor not found or not accessible') unless doctor
      end
      
      # Validate patient belongs to current practice if provided
      if params['patient_id']
        patient = practice_patients.find_by(id: params['patient_id'])
        raise_not_found('Patient not found or not accessible') unless patient
      end
      
      appointment = Appointment.new(filter_appointment_params(params))
      
      if appointment.save
        appointment.as_json(include: [:doctor, :patient])
      else
        raise_validation_error(appointment.errors.full_messages.join(', '))
      end
    end
    
    def handle_appointments_update(params)
      ensure_practice_exists!
      
      appointment = practice_appointments.find_by(id: params['id'])
      raise_not_found('Appointment not found') unless appointment
      
      if appointment.update(filter_appointment_params(params.except('id')))
        appointment.as_json(include: [:doctor, :patient])
      else
        raise_validation_error(appointment.errors.full_messages.join(', '))
      end
    end
    
    def handle_appointments_delete(params)
      ensure_practice_exists!
      
      appointment = practice_appointments.find_by(id: params['id'])
      raise_not_found('Appointment not found') unless appointment
      
      appointment.destroy
      { deleted: true }
    end
    
    # Datebook handlers
    def handle_datebooks_list(params)
      ensure_practice_exists!
      
      datebooks = practice_datebooks.order('name')
      
      if params['include_appointments'] != false
        datebooks.as_json(include: { appointments: { include: [:doctor, :patient] } })
      else
        datebooks.as_json
      end
    end
    
    def handle_datebooks_get(params)
      ensure_practice_exists!
      
      datebook = practice_datebooks.find_by(id: params['id'])
      raise_not_found('Datebook not found') unless datebook
      
      if params['include_appointments'] != false
        datebook.as_json(include: { appointments: { include: [:doctor, :patient] } })
      else
        datebook.as_json
      end
    end
    
    def handle_datebooks_create(params)
      ensure_practice_exists!
      
      datebook = practice_datebooks.build(filter_datebook_params(params))
      datebook.practice_id = current_user.practice_id
      
      if datebook.save
        datebook.as_json
      else
        raise_validation_error(datebook.errors.full_messages.join(', '))
      end
    end
    
    def handle_datebooks_update(params)
      ensure_practice_exists!
      
      datebook = practice_datebooks.find_by(id: params['id'])
      raise_not_found('Datebook not found') unless datebook
      
      if datebook.update(filter_datebook_params(params.except('id')))
        datebook.as_json
      else
        raise_validation_error(datebook.errors.full_messages.join(', '))
      end
    end
    
    def handle_datebooks_delete(params)
      ensure_practice_exists!
      
      datebook = practice_datebooks.find_by(id: params['id'])
      raise_not_found('Datebook not found') unless datebook
      
      unless datebook.is_deleteable
        raise_validation_error('Cannot delete datebook with existing appointments')
      end
      
      datebook.destroy
      { deleted: true }
    end
    
    # Helper methods
    def ensure_practice_exists!
      unless current_user&.practice_id
        raise StandardError, 'No practice associated with user'
      end
    end
    
    def practice_appointments
      Appointment.joins(:datebook)
        .where(datebooks: { practice_id: current_user.practice_id })
    end
    
    def practice_datebooks
      Datebook.with_practice(current_user.practice_id)
    end
    
    def practice_doctors
      Doctor.with_practice(current_user.practice_id)
    end
    
    def practice_patients
      Patient.with_practice(current_user.practice_id)
    end
    
    def filter_appointment_params(params)
      params.slice('datebook_id', 'doctor_id', 'patient_id', 'starts_at', 'ends_at', 'notes', 'status')
    end
    
    def filter_datebook_params(params)
      params.slice('name', 'starts_at', 'ends_at')
    end
    
    # MCP error handling
    def render_error(code, message, request_id)
      render json: {
        jsonrpc: '2.0',
        error: {
          code: code,
          message: message
        },
        id: request_id
      }, status: :bad_request
    end
    
    def raise_not_found(message)
      raise StandardError, message
    end
    
    def raise_validation_error(message)
      raise StandardError, message
    end
  end
end