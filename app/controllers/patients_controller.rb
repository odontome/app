class PatientsController < ApplicationController
  before_filter :require_user
  
  # provides
  respond_to :html, :json
  
  def index
    # this is the most frequent scenario, a simple list of patients
    if (params[:q] === nil)
      @patients = Patient.order("firstname").mine
    # otherwise, this is a search for patients
    else
      ActiveRecord::Base.include_root_in_json = false
      @patients = Patient.order("firstname").mine.select("id,uid,firstname,lastname").where("uid LIKE '%"+params[:q]+"%' OR firstname LIKE '%"+params[:q]+"%' OR lastname LIKE '%"+params[:q]+"%'").limit(10)
    end
    
    respond_with(@patients, :methods => :fullname)
  end

  def show
    @patient = Patient.mine.find(params[:id])
    @patient_notes = @patient.patient_notes
    
    if @patient.invalid?
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
        format.html { redirect_to(patients_url, :notice => _('The new patient was successfully created in your practice.')) }
      else
        format.html { render :action => "new" }
      end
    end
  end

  def update
    @patient = Patient.mine.find(params[:id])

    respond_to do |format|
      if @patient.update_attributes(params[:patient])
        format.html { redirect_to(@patient, :notice => _('Your practice\'s patient was successfully updated.')) }
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
    @appointments = Appointment.where("patient_id = ?", params[:id]).includes(:doctor).order( "starts_at desc")
    
    render :layout => nil
  end

end
