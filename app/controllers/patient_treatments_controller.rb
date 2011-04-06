class PatientTreatmentsController < ApplicationController
  before_filter :require_user
  
  # provides
  respond_to :js
  
  def index
    @patient = Patient.find(params[:patient_id])
    @treatments = PatientTreatment.order("tooth_number, updated_at ASC").where("patient_id = ?", params[:patient_id])
    @doctors = Doctor.order("firstname")
    @all_treatments = Treatment.mine.order("name")
    
    render :layout => nil
  end

  def show
    @treatment = PatientTreatment.find(params[:id])
  end

  def create
    @treatment = PatientTreatment.new(params[:patient_treatment])
    # this data is required to pass it down to the partial later on
    @patient = Patient.find(params[:patient_id])
    @doctors = Doctor.order("firstname")
    
    # FIXME (more of a enhance me) find the treatment passed and assign it
    treatment_used = Treatment.mine.find(params[:treatment_id])
    @treatment.patient_id = params[:patient_id]
    @treatment.name = treatment_used.name
    @treatment.price = treatment_used.price

    respond_to do |format|
      if @treatment.save
        format.js { } # create.js.erb
      else
        format.js  {
          render_ujs_error(@treatment, _("There was an error creating this entry"))
        }
      end
    end
  end

  def update
    @treatment = PatientTreatment.where("patient_id = ?", params[:patient_id]).find(params[:id])
    
    respond_to do |format|
      if @treatment.update_attributes(params[:patient_treatment])
        format.js { } # update.js.erb
      else
        format.js  {
          render_ujs_error(@treatment, _("There was an error updating this entry"))
        }
      end
    end
  end

  def destroy
    @treatment = PatientTreatment.find(params[:id])
    @treatment.destroy

    respond_to do |format|
      format.html { redirect_to(treatments_url) }
    end
  end

end
