class PatientsController < ApplicationController
  before_action :require_user
  before_action :require_practice_admin, only: [:destroy]

  # provides
  respond_to :html, :json

  def index
    # this is the most frequent scenario, a simple list of patients
    if params[:q].nil?
      # Always fetch the first letter of the first record, if not present
      # just send "A"
      if params[:letter].blank?
        first_patient = Patient.with_practice(current_user.practice_id).order('firstname ASC').first
        params[:letter] = first_patient.nil? ? 'A' : first_patient.firstname[0]
      end

      @patients = Patient.alphabetically(params[:letter]).with_practice(current_user.practice_id)

    else
      @patients = Patient.search(params[:q]).with_practice(current_user.practice_id)
    end

    respond_with(@patients, methods: :fullname)
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
    @patient = Patient.new(params[:patient])
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
      if @patient.update_attributes(params[:patient])
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
      format.html { redirect_to(patients_url) }
    end
  end
end
