# frozen_string_literal: true

class PatientsController < ApplicationController
  LETTER_PAGE_SIZE = 100

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
      resolve_letter_context
    end

    respond_to do |format|
      format.html # index.html
      format.json do
        render json: @patients, methods: :fullname
      end
      format.js
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

  def resolve_letter_context
    @current_letter = normalize_letter(params[:letter])
    scope = scope_for_letter(@current_letter)
    scoped = apply_letter_cursor(scope, params[:cursor])

    page = scoped.limit(LETTER_PAGE_SIZE + 1).to_a

    if page.length > LETTER_PAGE_SIZE
      last_patient = page.pop
      @next_cursor = encode_cursor(last_patient)
    else
      @next_cursor = nil
    end

    @patients = page
  end

  def scope_for_letter(letter)
    base_scope = if letter == '#'
                   Patient.anything_not_in_alphabet
                 else
                   Patient.anything_with_letter(letter)
                 end

    base_scope
      .with_practice(current_user.practice_id)
      .reorder('firstname ASC, lastname ASC, patients.id ASC')
  end

  def apply_letter_cursor(scope, cursor)
    return scope if cursor.blank?

    decoded = decode_cursor(cursor)
    return scope if decoded.blank?

    scope.where(
      'firstname > :firstname OR (firstname = :firstname AND (lastname > :lastname OR (lastname = :lastname AND patients.id > :id)))',
      firstname: decoded[:firstname],
      lastname: decoded[:lastname],
      id: decoded[:id]
    )
  end

  def normalize_letter(letter_param)
    return '#' if letter_param == '#'

    if letter_param.present?
      return letter_param.upcase if letter_param.match?(/\A[a-z]\z/i)

      return '#'
    end

    first_patient = Patient.with_practice(current_user.practice_id).order('firstname ASC').limit(1).first
    (first_patient&.firstname_initial || 'A').upcase
  end

  def encode_cursor(patient)
    payload = {
      firstname: patient.firstname.to_s,
      lastname: patient.lastname.to_s,
      id: patient.id
    }

    Base64.urlsafe_encode64(payload.to_json)
  end

  def decode_cursor(token)
    JSON.parse(Base64.urlsafe_decode64(token)).symbolize_keys
  rescue JSON::ParserError, ArgumentError
    nil
  end

  def patient_params
    params.require(:patient).permit(:uid, :firstname, :lastname, :fullname, :date_of_birth, :past_illnesses, :surgeries, :medications,
                                    :drugs_use, :cigarettes_per_day, :drinks_per_day, :family_diseases, :emergency_telephone, :email, :telephone, :mobile, :address, :allergies, :practice_id,
                                    :profile_picture, :remove_profile_picture)
  end
end
