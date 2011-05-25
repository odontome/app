class DoctorsController < ApplicationController
  before_filter :require_user
  
  def index
    @doctors = Doctor.mine
  end

  def show
    @doctor = Doctor.mine.find(params[:id])
  end

  def new
    @doctor = Doctor.new
  end

  def edit
    @doctor = Doctor.mine.find(params[:id])
  end

  def create
    @doctor = Doctor.new(params[:doctor])

    respond_to do |format|
      if @doctor.save
        format.html { redirect_to(doctors_url, :notice => _('The new doctor was successfully created in your practice.')) }
      else
        format.html { render :action => "new" }
      end
    end
  end

  def update
    @doctor = Doctor.mine.find(params[:id])

    respond_to do |format|
      if @doctor.update_attributes(params[:doctor])
        format.html { redirect_to(doctors_url, :notice => _('Your practice\'s doctor was successfully updated.')) }
      else
        format.html { render :action => "edit" }
      end
    end
  end

  def destroy
    @doctor = Doctor.mine.find(params[:id])
    
    # Check if this doctor can be deleted, otherwise toggle his validness
    if @doctor.is_deleteable
      @doctor.destroy
    else 
      @doctor.is_active = !@doctor.is_active
      @doctor.save
    end

    respond_to do |format|
      format.html { redirect_to(doctors_url) }
    end
  end

end
