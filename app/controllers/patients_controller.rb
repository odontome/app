class PatientsController < ApplicationController
  before_filter :require_user
  
  def index
    # this is the most frequent scenario, a simple list of patients
    if (params[:q] === nil)
      @patients = Patient.mine
    # otherwise, this is a search for patients
    else
      @patients = Patient.mine.where(t[:uid].matches("%1").or(t[:first_name].matches("%Ra%")).or(t[:last_name].matches("%Riera%")))
    end
    
  end

  def show
    @patient = Patient.mine.find(params[:id])
    @patient_notes = @patient.patient_notes
    
    respond_to do |format|
      format.html # show.html.erb
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
        format.html { redirect_to(patients_url, :notice => _('Patient was successfully created.')) }
      else
        format.html { render :action => "new" }
      end
    end
  end

  def update
    @patient = Patient.mine.find(params[:id])

    respond_to do |format|
      if @patient.update_attributes(params[:patient])
        format.html { redirect_to(@patient, :notice => _('Patient was successfully updated.')) }
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
  
  def appointments 
    @appointments = Appointment.where("patient_id = ?", params[:id]).includes(:doctors).order( "starts_at desc")
    
    render :layout => nil
  end

end
