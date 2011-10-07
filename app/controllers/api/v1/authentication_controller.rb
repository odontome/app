class Api::V1::AuthenticationController < Api::V1::BaseController
	
	before_filter :authenticate_user!, :only => :destroy
	
	def create	
		begin
			# fetch the user by email, so we can check his password later
			user_by_email = User.where(:email => params[:email]).first
			
			# fetch the user by the password and email	
			user = User.where(:crypted_password => Authlogic::CryptoProviders::Sha512.encrypt(params[:password] + user_by_email.password_salt)).where(:email => params[:email]).first
		rescue
			render :json => { :error => "Invalid credentials." }, :status => 404
		end
		
		respond_with user, :only => [:id, :firstname, :lastname, :authentication_token]
	end
	
	def destroy
		current_user_session.destroy
		respond_with({:success => "Logged out successfully." })
	end

end