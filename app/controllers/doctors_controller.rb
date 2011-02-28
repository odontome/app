class DoctorsController < ApplicationController
  before_filter :require_user
  
  def index
    @doctors = Doctor.all
  end

  def show
    @doctor = Doctor.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
    end
  end

  def new
    @doctor = Doctor.new
  end

  def edit
    @doctor = Doctor.find(params[:id])
  end

  def create
    @doctor = Doctor.new(params[:doctor])

    respond_to do |format|
      if @doctor.save
        format.html { redirect_to(doctors_url, :notice => 'Doctor was successfully created.') }
      else
        format.html { render :action => "new" }
      end
    end
  end

  def activation
    @doctor = Doctor.find(params[:id])
    if @doctor.is_acticve
      @doctor.is_acticve = false
    else
      @doctor.is_acticve = true
    end

    respond_to do |format|
      if @doctor.save
        format.html { redirect_to(doctors_url, :notice => 'Doctor status was successfully updated.') }
      else
        format.html { render :action => "show" }
      end
    end
  end


  def destroy
    @doctor = Doctor.find(params[:id])
    @doctor.destroy

    respond_to do |format|
      format.html { redirect_to(doctors_url) }
    end
  end

end
