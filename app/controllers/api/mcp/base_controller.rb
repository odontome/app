# frozen_string_literal: true

module Api::Mcp
  # Base controller for all MCP API endpoints
  # 
  # To add new models to the MCP:
  # 1. Create a new controller inheriting from BaseController
  # 2. Add routes in config/routes.rb under the :mcp namespace
  # 3. Implement CRUD methods following the pattern in AppointmentsController
  # 4. Ensure proper practice scoping for security
  # 5. Add comprehensive tests
  #
  # Example:
  #   class PatientsController < BaseController
  #     def index
  #       @patients = Patient.with_practice(current_user.practice_id)
  #       render_success(@patients)
  #     end
  #   end
  class BaseController < ApplicationController
    # Skip CSRF protection for API endpoints
    skip_forgery_protection
    
    # Require user authentication for all MCP endpoints
    before_action :require_user
    
    # JSON responses only
    respond_to :json
    
    private
    
    # Render validation errors in JSON format
    def render_validation_errors(object)
      render json: {
        errors: object.errors.full_messages
      }, status: :unprocessable_entity
    end
    
    # Render success response
    def render_success(object, status: :ok)
      render json: object, status: status
    end
    
    # Render not found error
    def render_not_found(message = 'Record not found')
      render json: { error: message }, status: :not_found
    end
    
    # Ensure current user has a practice
    def ensure_practice_exists
      unless current_user&.practice_id
        render json: { error: 'No practice associated with user' }, status: :forbidden
        return false
      end
    end
  end
end