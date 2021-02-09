class Api::V1::DoctorsController < Api::V1::BaseController
  
  before_action :find_doctor, :only => [:show]
  
  def index
    respond_with(Doctor.with_practice(current_user.practice_id).valid, :methods => "fullname")
  end
  
  def show
    respond_with(@doctor, :methods => ["fullname"])
  end
  
  def create
    doctor = Doctor.create(params[:doctor])
    
    if doctor.valid?
      respond_with(doctor, :location => api_v1_doctor_path(doctor))
    else
      respond_with(doctor)
  	end 
  end
  
  def show
    respond_with(@doctor)
  end
  
  def update
  	@doctor.update_attributes(params[:doctor])
		respond_with(@doctor)
  end
  
  # def destroy
  #   @doctor.destroy
  #   respond_with(@doctor)
  # end
  
  private
  
  def find_doctor
  	@doctor = Doctor.with_practice(current_user.practice_id).find(params[:id])
  	rescue ActiveRecord::RecordNotFound
  		error = { :error => "The doctor you were looking for could not be found."}
  		respond_with(error, :status => 404)
  end
  
end