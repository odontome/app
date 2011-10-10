class Api::V1::DoctorsController < Api::V1::BaseController
  
  before_filter :find_doctor, :only => [:show]
  
  def index
    respond_with(Doctor.mine, :methods => "fullname")
  end
  
  def show
    respond_with(@doctor)
  end
  
  private
  
  def find_doctor
  	@doctor = Doctor.mine.find(params[:id])
  	rescue ActiveRecord::RecordNotFound
  		error = { :error => "The doctor you were looking for could not be found."}
  		respond_with(error, :status => 404)
  end
  
end