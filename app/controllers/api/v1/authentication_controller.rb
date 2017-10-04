class Api::V1::AuthenticationController < Api::V1::BaseController

	before_action :authenticate_user!, :only => :destroy

	def create
		begin
			user = User.where(:email => params[:email]).first

			if user.valid_password? params[:password]
				respond_with user, :only => [:id, :firstname, :lastname, :roles, :authentication_token]
			else
				render :json => { :error => "Invalid credentials." }, :status => 404
			end

		rescue
			render :json => { :error => "Invalid credentials." }, :status => 404
		end
	end

end
