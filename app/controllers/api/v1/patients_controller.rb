class Api::V1::PatientsController < Api::V1::BaseController
  
  before_filter :find_patient, :only => [:show, :update, :destroy]
  
  def index
    respond_with Patient.mine, :only => [:id, :uid, :firstname, :lastname, :updated_at], :methods => [:fullname, :age]
  end
  
  def show
    respond_with(@patient, :methods => "notes")
  end
  
  def create
    patient = Patient.create(params[:patient])
    
    if patient.valid?
      respond_with(patient, :location => api_v1_patient_path(patient))
    else
      respond_with(patient)
  	end 
  end
  
  def update
  	@patient.update_attributes(params[:patient])  	
		respond_with(@patient)
  end
  
  # def destroy
  #   @patient.destroy
  #   respond_with(@patient)
  # end
  
  private
  
  def find_patient
  	@patient = Patient.mine.find(params[:id])
  	rescue ActiveRecord::RecordNotFound
  		error = { :error => "The patient you were looking for could not be found."}
  		respond_with(error, :status => 404)
  end
  
end