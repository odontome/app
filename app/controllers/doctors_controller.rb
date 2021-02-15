# frozen_string_literal: true

class DoctorsController < ApplicationController
  # filters
  before_action :require_user, except: :appointments

  def index
    @doctors = Doctor.with_practice(current_user.practice_id)
  end

  def show
    @doctor = Doctor.with_practice(current_user.practice_id).find(params[:id])
    @appointments = @doctor.appointments.joins(:patient).where('starts_at > ?', Date.today).order('starts_at desc')
  end

  def new
    @doctor = Doctor.new
  end

  def edit
    @doctor = Doctor.with_practice(current_user.practice_id).find(params[:id])
  end

  def create
    @doctor = Doctor.new(params[:doctor])
    @doctor.practice_id = current_user.practice_id

    respond_to do |format|
      if @doctor.save
        format.html { redirect_to(doctors_url, notice: t(:doctor_created_success_message)) }
      else
        format.html { render action: 'new' }
      end
    end
  end

  def update
    @doctor = Doctor.with_practice(current_user.practice_id).find(params[:id])

    respond_to do |format|
      if @doctor.update_attributes(params[:doctor])
        format.html { redirect_to(doctors_url, notice: t(:doctor_updated_success_message)) }
      else
        format.html { render action: 'edit' }
      end
    end
  end

  def destroy
    @doctor = Doctor.with_practice(current_user.practice_id).find(params[:id])

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
    doctor_id_deciphered = Cipher.decode(params[:doctor_id])
    @doctor = Doctor.find_by id: doctor_id_deciphered, is_active: true

    start_of_week = Date.today.at_beginning_of_week.to_time.to_i
    end_of_week = start_of_week + 2.weeks

    @appointments = @doctor.appointments.find_between(start_of_week, end_of_week).includes(:patient)

    respond_to do |format|
      format.ics { render ics: @appointments }
    end
  end
end
