class PatientsController < ApplicationController
  before_filter :require_user
  
  def index
    @patients = Patient.mine
  end

  def show
    @patient = Patient.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
    end
  end

  def new
    @patient = Patient.new
  end

  def edit
    @patient = Patient.find(params[:id])
  end

  def create
    @patient = Patient.new(params[:patient])

    respond_to do |format|
      if @patient.save
        format.html { redirect_to(patients_url, :notice => 'Patient was successfully created.') }
      else
        format.html { render :action => "new" }
      end
    end
  end

  def destroy
    @patient = patient.find(params[:id])
    @patient.destroy

    respond_to do |format|
      format.html { redirect_to(patients_url) }
    end
  end


end
