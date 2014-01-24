class ErrorsController < ApplicationController
  def not_found
    render :status => 404, :formats => [:html]
  end

  def server_error
    render :status => 500, :formats => [:html]
  end

  def unauthorized
  	render :status => 401, :formats => [:html]
  end
end