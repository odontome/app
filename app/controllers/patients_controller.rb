# frozen_string_literal: true

class PatientsController < ApplicationController
  before_action :require_user
  before_action :require_practice_admin, only: [:destroy]

  def index
    if params[:term].present?
      @patients = Patient.search(params[:term]).with_practice(current_user.practice_id)
    elsif params[:segment].present? && params[:segment] == 'new_this_week'
      # Align with KPI: use practice timezone and current calendar week (Mon–Sun), inclusive
      tz = ActiveSupport::TimeZone[current_user.practice.timezone] || Time.zone
      week_start = tz.now.beginning_of_week
      week_end = tz.now.end_of_week
      @patients = Patient
                  .with_practice(current_user.practice_id)
                  .where('created_at >= ? AND created_at <= ?', week_start, week_end)
    else
      # Always fetch the first letter of the first record, if not present
      # just send "A"
      if params[:letter].blank?
        first_patient = Patient.with_practice(current_user.practice_id).order('firstname ASC').limit(1).first
        params[:letter] = first_patient&.firstname&.first || 'A'
      end

      # if the provided letter is not in the alphabet, send back anything else
      @patients = if [*'a'..'z'].include?(params[:letter].downcase)
                    Patient.anything_with_letter(params[:letter]).with_practice(current_user.practice_id)
                  else
                    Patient.anything_not_in_alphabet.with_practice(current_user.practice_id)
                  end
    end

    respond_to do |format|
      format.html # index.html
      format.json do
        render json: @patients, methods: :fullname
      end
    end
  end

  def show
    @patient = Patient.with_practice(current_user.practice_id).find(params[:id])
    @patient_notes = @patient.notes.includes(:user).order('created_at DESC')
    @appointments = Appointment.find_all_past_and_future_for_patient @patient.id
    @total_balance = Balance.where('patient_id = ?', @patient.id).sum(:amount)

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
    @patient = Patient.with_practice(current_user.practice_id).find(params[:id])
  end

  def create
    @patient = Patient.new(patient_params)
    @patient.practice_id = current_user.practice_id

    respond_to do |format|
      if @patient.save
        format.html { redirect_to(@patient, notice: I18n.t(:patient_created_success_message)) }
      else
        format.html { render action: 'new' }
      end
    end
  end

  def update
    @patient = Patient.with_practice(current_user.practice_id).find(params[:id])

    respond_to do |format|
      if @patient.update(patient_params)
        format.html { redirect_to(@patient, notice: I18n.t(:patient_updated_success_message)) }
      else
        format.html { render action: 'edit' }
      end
    end
  end

  def destroy
    @patient = Patient.with_practice(current_user.practice_id).find(params[:id])
    @patient.destroy
    respond_to do |format|
      format.html { redirect_to(patients_path, notice: I18n.t(:patient_deleted_success_message)) }
    end
  end

  private

  def patient_params
    params.require(:patient).permit(:uid, :firstname, :lastname, :fullname, :date_of_birth, :past_illnesses, :surgeries, :medications,
                                    :drugs_use, :cigarettes_per_day, :drinks_per_day, :family_diseases, :emergency_telephone, :email, :telephone, :mobile, :address, :allergies, :practice_id,
                                    :profile_picture_url)
  end
end
