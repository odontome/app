# frozen_string_literal: true

class ErrorsController < ApplicationController
  layout 'simple'
  skip_before_action :check_consent_status

  def not_found
    render status: 404, formats: [:html]
  end

  def server_error
    render status: 500, formats: [:html]
  end

  def unauthorised
    render status: 401, formats: [:html]
  end
end
