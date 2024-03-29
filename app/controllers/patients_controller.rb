# frozen_string_literal: true

class PatientsController < ApplicationController
  before_action :require_user
  before_action :require_practice_admin, only: [:destroy]

  def index
    # this is the most frequent scenario, a simple list of patients
    if params[:term].nil?
      # Always fetch the first letter of the first record, if not present
      # just send "A"
      if params[:letter].blank?
        first_patient = Patient.with_practice(current_user.practice_id).order('firstname ASC').limit(1).first
        params[:letter] = first_patient&.firstname&.first || 'A'
      end

      # iI the provided is not in the alphabet, send back anything else
      if [*'a'..'z'].include?(params[:letter].downcase)
        @patients = Patient.anything_with_letter(params[:letter]).with_practice(current_user.practice_id)
      else
        @patients = Patient.anything_not_in_alphabet.with_practice(current_user.practice_id)
      end
    else
      @patients = Patient.search(params[:term]).with_practice(current_user.practice_id)
    end

    respond_to do |format|
      format.html # index.html
      format.json { 
        render json: @patients, methods: :fullname
      }
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
    back_to = request.referer || patients_path

    @patient = Patient.with_practice(current_user.practice_id).find(params[:id])
    @patient.destroy
    respond_to do |format|
      format.html { redirect_to(back_to) }
    end
  end

  private

  def patient_params
    params.require(:patient).permit(:uid, :firstname, :lastname, :fullname, :date_of_birth, :past_illnesses, :surgeries, :medications,
                                    :drugs_use, :cigarettes_per_day, :drinks_per_day, :family_diseases, :emergency_telephone, :email, :telephone, :mobile, :address, :allergies, :practice_id)
  end
end
