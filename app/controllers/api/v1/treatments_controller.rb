class Api::V1::TreatmentsController < Api::V1::BaseController
  
  before_action :find_treatment, :only => [:show]
  
  def index
    respond_with(Treatment.with_practice(current_user.practice_id).valid, :only => [:id, :name, :price])
  end
  
  def show
    respond_with(@treatment)
  end
  
  def create
    treatment = Treatment.create(params[:treatment])
    
    if treatment.valid?
      respond_with(treatment, :location => api_v1_treatment_path(treatment))
    else
      respond_with(treatment)
  	end 
  end
  
  def show
    respond_with(@treatment)
  end
  
  def update
  	@treatment.update_attributes(params[:treatment])
		respond_with(@treatment)
  end
  
  private
  
  def find_treatment
  	@treatment = Treatment.with_practice(current_user.practice_id).find(params[:id])
  	rescue ActiveRecord::RecordNotFound
  		error = { :error => "The treatment you were looking for could not be found."}
  		respond_with(error, :status => 404)
  end
  
end