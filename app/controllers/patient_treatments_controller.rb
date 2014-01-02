class PatientTreatmentsController < ApplicationController  
  before_filter :require_user
  
  # provides
  respond_to :js
  
  def index
    @patient = Patient.mine.find(params[:patient_id])
    @treatments = PatientTreatment.order("created_at").where("patient_id = ?", params[:patient_id])
    @doctors = Doctor.mine.valid.order("firstname")
    @all_treatments = Treatment.mine.valid
    
    render :layout => nil
  end

  def show
    @treatment = PatientTreatment.find(params[:id])
  end

  def create
    @treatment = PatientTreatment.new(params[:patient_treatment])
    # this data is required to pass it down to the partial later on
    @patient = Patient.mine.find(params[:patient_id])
    @doctors = Doctor.mine.valid.order("firstname")
    
    # FIXME (more of a enhance me) find the treatment passed and assign it
    if params[:treatment_id] != nil
      treatment_used = Treatment.mine.find(params[:treatment_id])
      @treatment.patient_id = params[:patient_id]
      @treatment.name = treatment_used.name
      @treatment.price = treatment_used.price
    end

    respond_to do |format|
      if @treatment.save
        format.js { } # create.js.erb
      else
        format.js  {
          render_ujs_error(@treatment, I18n.t(:patient_treatment_created_error_message))
        }
      end
    end
  end

  def update
  	# this data is required to pass it down to the partial later on
  	@patient = Patient.mine.find(params[:patient_id])
  	@doctors = Doctor.mine.valid.order("firstname")
  
    @treatment = PatientTreatment.where("patient_id = ?", @patient.id).find(params[:id])
    
    respond_to do |format|
      if @treatment.update_attributes(params[:patient_treatment])
        format.js { } # update.js.erb
      else
        format.js  {
          render_ujs_error(@treatment, I18n.t(:patient_treatment_updated_error_message))
        }
      end
    end
  end

  def destroy
    @treatment = PatientTreatment.find(params[:id])
    @treatment.destroy

    respond_to do |format|
      format.js { } # destroy.js.erb
    end
  end

end
