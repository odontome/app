class DoctorsController < ApplicationController
  # filters
  before_filter :require_user, :except => :appointments

  # provides
  respond_to :ics, :only => [:appointments]

  def index
    @doctors = Doctor.mine
  end

  def show
    @doctor = Doctor.mine.find(params[:id])
    @appointments = @doctor.appointments.joins(:patient).where("starts_at > ?", Date.today).order("starts_at desc")
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
        format.html { redirect_to(doctors_url, :notice => t(:doctor_created_success_message))}
      else
        format.html { render :action => "new" }
      end
    end
  end

  def update
    @doctor = Doctor.mine.find(params[:id])

    respond_to do |format|
      if @doctor.update_attributes(params[:doctor])
        format.html { redirect_to(doctors_url, :notice => t(:doctor_updated_success_message)) }
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

  def appointments
    cipher = Gibberish::AES.new(Rails.configuration.secret_token)

    doctor_id_deciphered = cipher.dec(Base64.strict_decode64(params[:doctor_id]))
    doctor = Doctor.find(doctor_id_deciphered)

    start_of_week = Date.today.at_beginning_of_week.to_time.to_i
    end_of_week = start_of_week + 2.weeks

    @appointments = doctor.appointments.find_between(start_of_week, end_of_week).includes(:patient)

    respond_with(@appointments)
  end

end
