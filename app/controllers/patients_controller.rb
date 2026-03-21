# frozen_string_literal: true

class PatientsController < ApplicationController
  LETTER_PAGE_SIZE = 100
  SORT_NAME = 'name'
  SORT_LAST_VISIT = 'last_visit'
  SORT_ASC = 'asc'
  SORT_DESC = 'desc'

  before_action :require_user
  before_action :require_practice_admin, only: [:destroy]

  def index
    if params[:term].present?
      @patients = with_last_visit_for_listing(
        Patient.search(params[:term]).with_practice(current_user.practice_id)
      )
    elsif params[:segment].present? && params[:segment] == 'new_this_week'
      # Align with KPI: use practice timezone and current calendar week (Mon–Sun), inclusive
      tz = ActiveSupport::TimeZone[current_user.practice.timezone] || Time.zone
      week_start = tz.now.beginning_of_week
      week_end = tz.now.end_of_week
      @patients = with_last_visit_for_listing(
        Patient
          .with_practice(current_user.practice_id)
          .where('created_at >= ? AND created_at <= ?', week_start, week_end)
      )
    elsif infer_all_segment?
      @segment = 'all'
      resolve_letter_context
    else
      @segment = 'today'
      resolve_today_context
    end

    @patients ||= [] # guard for json/js formats when on Today segment

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

  def resolve_today_context
    practice = current_user.practice
    @appointments = Appointment.today_for_practice(practice.id, practice.timezone)
    @today_count = @appointments.size
  end

  def infer_all_segment?
    params[:segment] == 'all' ||
      params[:letter].present? ||
      params[:sort].present? ||
      params[:cursor].present?
  end

  def today_appointment_count
    practice = current_user.practice
    tz = ActiveSupport::TimeZone[practice.timezone] || Time.zone

    Appointment
      .joins(:patient)
      .where(patients: { practice_id: practice.id })
      .where(status: [Appointment.status[:confirmed], Appointment.status[:waiting_room]])
      .where(starts_at: tz.now.beginning_of_day..tz.now.end_of_day)
      .count
  end

  def resolve_letter_context
    @today_count = today_appointment_count
    @current_letter = normalize_letter(params[:letter])
    @sort_column = normalize_sort_column(params[:sort])
    @sort_direction = normalize_sort_direction(params[:direction], @sort_column)

    patients = patients_for_letter(
      @current_letter,
      cursor: params[:cursor],
      sort_column: @sort_column,
      sort_direction: @sort_direction
    )

    page = patients.limit(LETTER_PAGE_SIZE + 1).to_a
    visible_patients = page.first(LETTER_PAGE_SIZE)

    @next_cursor = if page.length > LETTER_PAGE_SIZE && visible_patients.any?
                     encode_cursor(
                       visible_patients.last,
                       sort_column: @sort_column,
                       sort_direction: @sort_direction
                     )
                   else
                     nil
                   end

    @patients = visible_patients
  end

  def patients_for_letter(letter, cursor: nil, sort_column:, sort_direction:)
    base_scope = if letter == '#'
                   Patient.anything_not_in_alphabet
                 else
                   Patient.anything_with_letter(letter)
                 end

    scoped = with_last_visit_for_listing(
      base_scope.with_practice(current_user.practice_id)
    )

    scoped = apply_listing_sort(scoped, sort_column: sort_column, sort_direction: sort_direction)

    return scoped if cursor.blank?

    decoded = decode_cursor(cursor)
    return scoped if decoded.blank?

    cursor_sort_column = decoded[:sort_column].presence || SORT_NAME
    cursor_sort_direction = decoded[:sort_direction].presence || SORT_ASC

    return scoped unless cursor_sort_column == sort_column && cursor_sort_direction == sort_direction

    apply_cursor_scope(scoped, decoded, sort_column: sort_column, sort_direction: sort_direction)
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

  def normalize_sort_column(sort_column_param)
    allowed_columns = [SORT_NAME, SORT_LAST_VISIT]
    normalized = sort_column_param.to_s

    allowed_columns.include?(normalized) ? normalized : SORT_NAME
  end

  def normalize_sort_direction(sort_direction_param, sort_column)
    default_direction = sort_column == SORT_LAST_VISIT ? SORT_DESC : SORT_ASC
    normalized = sort_direction_param.to_s.downcase

    [SORT_ASC, SORT_DESC].include?(normalized) ? normalized : default_direction
  end

  def encode_cursor(patient, sort_column:, sort_direction:)
    payload = {
      id: patient.id,
      sort_column: sort_column,
      sort_direction: sort_direction
    }

    if sort_column == SORT_LAST_VISIT
      payload[:last_visit_at] = patient.last_visit_at&.iso8601
    else
      payload[:firstname] = patient.firstname.to_s
      payload[:lastname] = patient.lastname.to_s
    end

    Base64.urlsafe_encode64(payload.to_json)
  end

  def decode_cursor(token)
    JSON.parse(Base64.urlsafe_decode64(token)).symbolize_keys
  rescue JSON::ParserError, ArgumentError
    nil
  end

  def with_last_visit_for_listing(scope)
    scope
      .joins(last_visit_join_sql)
      .select('last_visits.last_visit_at AS last_visit_at')
  end

  CONFIRMED_STATUS_SQL = ActiveRecord::Base.connection.quote('confirmed').freeze

  def last_visit_join_sql
    <<~SQL.squish
      LEFT JOIN LATERAL (
        SELECT appointments.ends_at AS last_visit_at
        FROM appointments
        WHERE appointments.patient_id = patients.id
          AND appointments.status = #{CONFIRMED_STATUS_SQL}
          AND appointments.ends_at <= CURRENT_TIMESTAMP
        ORDER BY appointments.ends_at DESC
        LIMIT 1
      ) last_visits ON TRUE
    SQL
  end

  def apply_listing_sort(scope, sort_column:, sort_direction:)
    if sort_column == SORT_LAST_VISIT
      last_visit_direction = sort_direction == SORT_ASC ? 'ASC' : 'DESC'

      return scope.reorder(
        Arel.sql("CASE WHEN last_visits.last_visit_at IS NULL THEN 1 ELSE 0 END ASC, last_visits.last_visit_at #{last_visit_direction}, patients.id ASC")
      )
    end

    name_direction = sort_direction == SORT_DESC ? 'DESC' : 'ASC'
    scope.reorder("firstname #{name_direction}, lastname #{name_direction}, patients.id #{name_direction}")
  end

  def apply_cursor_scope(scope, decoded, sort_column:, sort_direction:)
    if sort_column == SORT_LAST_VISIT
      return apply_last_visit_cursor_scope(scope, decoded, sort_direction: sort_direction)
    end

    apply_name_cursor_scope(scope, decoded, sort_direction: sort_direction)
  end

  def apply_name_cursor_scope(scope, decoded, sort_direction:)
    comparator = sort_direction == SORT_DESC ? '<' : '>'

    scope.where(
      "firstname #{comparator} :firstname OR (firstname = :firstname AND (lastname #{comparator} :lastname OR (lastname = :lastname AND patients.id #{comparator} :id)))",
      firstname: decoded[:firstname].to_s,
      lastname: decoded[:lastname].to_s,
      id: decoded[:id].to_i
    )
  end

  def apply_last_visit_cursor_scope(scope, decoded, sort_direction:)
    cursor_last_visit = parse_cursor_time(decoded[:last_visit_at])
    cursor_id = decoded[:id].to_i

    if cursor_last_visit.nil?
      return scope.where('last_visits.last_visit_at IS NULL AND patients.id > :id', id: cursor_id)
    end

    comparator = sort_direction == SORT_ASC ? '>' : '<'

    scope.where(
      "(last_visits.last_visit_at IS NOT NULL AND (last_visits.last_visit_at #{comparator} :last_visit OR (last_visits.last_visit_at = :last_visit AND patients.id > :id))) OR last_visits.last_visit_at IS NULL",
      last_visit: cursor_last_visit,
      id: cursor_id
    )
  end

  def parse_cursor_time(value)
    return nil if value.blank?

    Time.zone.parse(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end

  def patient_params
    params.require(:patient).permit(:uid, :firstname, :lastname, :fullname, :date_of_birth, :past_illnesses, :surgeries, :medications,
                                    :drugs_use, :cigarettes_per_day, :drinks_per_day, :family_diseases, :emergency_telephone, :email, :telephone, :mobile, :address, :allergies, :practice_id,
                                    :profile_picture, :remove_profile_picture)
  end
end
