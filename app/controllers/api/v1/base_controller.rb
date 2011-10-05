class Api::V1::BaseController < ActionController::Base
  
  before_filter :authenticate_user!
  before_filter :authorize_admin!, :only => [:destroy] 
  
  respond_to :json
  
  private
  
  def authenticate_user!
  	@current_user = User.find_by_authentication_token(params[:token])
  	 	
  	if @current_user && !@current_user.authentication_token.nil?
  		@current_user = UserSession.create(@current_user)
 		else
  		respond_with({:error => "Token is invalid." }, :status => 401)
  	end
  end
  
  def current_user!
  	@current_user
  end
  
  def authorize_admin!
    authenticate_user!
    unless @current_user.user.roles.include?("admin")
    	error = { :error => _('Sorry, you need to be an administrator of your practice to do that.') }
      render params[:format].to_sym => error, :status => 401
    end
  end
  
end