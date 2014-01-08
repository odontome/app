class Api::V1::BaseController < ActionController::Base
  
  before_filter :authenticate_user!
  before_filter :authorize_admin!, :only => [:destroy] 
  
  respond_to :json
  
  private
  
  def authenticate_user!

    authenticate_or_request_with_http_token do |token, options|
      @current_user = User.find_by_authentication_token(token)

      if @current_user && !@current_user.authentication_token.nil?
        @current_user = UserSession.create(@current_user)
      else
        render :json => {:error => "Token is invalid." }, :status => 401
      end

    end
	
  end
  
  def current_user!
  	@current_user
  end
  
  def authorize_admin!
    authenticate_user!
    unless @current_user.user.roles.include?("admin")
      render :json => { :error => 'Sorry, you need to be an administrator of your practice to do that.' }, :status => 403
    end
  end
  
end