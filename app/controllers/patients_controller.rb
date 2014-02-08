class PatientsController < ApplicationController
  before_filter :require_user
  before_filter :require_practice_admin, :only => [:destroy]
  
  # provides
  respond_to :html, :json
  
  def index
    # this is the most frequent scenario, a simple list of patients
    if (params[:q] === nil)
    	# Always fetch the first letter of the first record, if not present
    	# just send "A"
    	if params[:letter].blank?
    		first_patient = Patient.mine.order("firstname ASC").first
    		params[:letter] = first_patient.nil? ? "A" : first_patient.firstname[0]
    	end

      @patients = Patient.alphabetically params[:letter]
    # otherwise, this is a search for patients
    else
      @patients = Patient.search(params[:q])
    end
        
    respond_with(@patients, :methods => :fullname)
  end

  def show
    @patient = Patient.mine.find(params[:id])
    @patient_notes = @patient.notes.order("created_at DESC")
    @appointments = Appointment.where("patient_id = ?", @patient.id).includes(:doctor).order("starts_at desc")

    if @patient.missing_info?
      redirect_to edit_patient_path(@patient)
    else 
      respond_to do |format|
        format.html # show.html.erb
      end
    end
  end

  def new
    @patient = Patient.new
  end

  def edit
    @patient = Patient.mine.find(params[:id])
  end

  def create
    @patient = Patient.new(params[:patient])

    respond_to do |format|
      if @patient.save
        format.html { redirect_to(@patient, :notice => I18n.t(:patient_created_success_message)) }
      else
        format.html { render :action => "new" }
      end
    end
  end

  def update
    @patient = Patient.mine.find(params[:id])

    respond_to do |format|
      if @patient.update_attributes(params[:patient])
        format.html { redirect_to(@patient, :notice => I18n.t(:patient_updated_success_message)) }
      else
        format.html { render :action => "edit" }
      end
    end
  end

  def destroy
    @patient = Patient.mine.find(params[:id])
    @patient.destroy

    respond_to do |format|
      format.html { redirect_to(patients_url) }
    end
  end
  
end
