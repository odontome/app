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
        format.html { redirect_to(doctors_url, :notice => _('Doctor was successfully created.')) }
      else
        format.html { render :action => "new" }
      end
    end
  end

  def update
    @doctor = Doctor.mine.find(params[:id])

    respond_to do |format|
      if @doctor.update_attributes(params[:doctor])
        format.html { redirect_to(@doctor, :notice => _('Doctor was successfully updated.')) }
      else
        format.html { render :action => "edit" }
      end
    end
  end

  def destroy
    @doctor = Doctor.mine.find(params[:id])
    @doctor.destroy

    respond_to do |format|
      format.html { redirect_to(doctors_url) }
    end
  end

end
