# frozen_string_literal: true

class PatientsController < ApplicationController
  include CursorPaginatable

  LETTER_PAGE_SIZE = 100
  SORT_NAME = 'name'
  SORT_LAST_VISIT = 'last_visit'
  SORT_ASC = 'asc'
  SORT_DESC = 'desc'

  before_action :require_user
  before_action :require_practice_admin, only: [:destroy]

  def index
    if params[:term].present?
      @patients = Patient.search(params[:term]).with_practice(current_user.practice_id).with_last_visit
    elsif params[:segment].present? && params[:segment] == 'new_this_week'
      @patients = Patient.with_practice(current_user.practice_id)
                         .new_this_week(current_user.practice.timezone)
                         .with_last_visit
    elsif params[:segment] == 'needs_follow_up'
      @segment = 'needs_follow_up'
      resolve_needs_follow_up_context
    elsif params[:segment] == 'birthdays'
      @segment = 'birthdays'
      resolve_birthdays_context
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
    @follow_up_count = needs_follow_up_count
    @birthday_count = birthday_this_week_count
    @show_datebook = practice.datebooks_count.to_i > 1
  end

  def load_segment_counts
    practice = current_user.practice
    @today_count = Appointment.today_for_practice(practice.id, practice.timezone).count
    @follow_up_count = needs_follow_up_count
    @birthday_count = birthday_this_week_count
  end

  def resolve_birthdays_context
    load_segment_counts

    @patients = Patient.with_practice(current_user.practice_id)
                       .birthday_this_week(current_user.practice.timezone)
                       .reorder(Arel.sql("EXTRACT(MONTH FROM date_of_birth), EXTRACT(DAY FROM date_of_birth)"))
  end

  def resolve_needs_follow_up_context
    load_segment_counts

    base_scope = Patient.with_practice(current_user.practice_id)
      .needs_follow_up
      .reorder("last_visits.last_visit_at ASC NULLS FIRST, patients.id ASC")

    offset = [params[:offset].to_i, 0].max
    page = base_scope.limit(LETTER_PAGE_SIZE + 1).offset(offset).to_a
    @patients = page.first(LETTER_PAGE_SIZE)
    @next_follow_up_offset = page.length > LETTER_PAGE_SIZE ? offset + LETTER_PAGE_SIZE : nil
  end

  def infer_all_segment?
    params[:segment] == 'all' ||
      params[:letter].present? ||
      params[:sort].present? ||
      params[:cursor].present?
  end

  def birthday_this_week_count
    Patient.with_practice(current_user.practice_id)
      .birthday_this_week(current_user.practice.timezone)
      .count
  end

  def needs_follow_up_count
    Patient.with_practice(current_user.practice_id)
      .needs_follow_up
      .reselect('patients.id')
      .count
  end

  def letter_options_for_practice
    present_initials = Patient.with_practice(current_user.practice_id)
                              .where.not(firstname_initial: nil)
                              .reorder('')
                              .distinct
                              .pluck(:firstname_initial)
                              .map(&:downcase)

    alpha_set = Set.new(present_initials.select { |i| i.match?(/\A[a-z]\z/) }.map(&:upcase))
    @has_non_alpha_patients = present_initials.any? { |i| !i.match?(/\A[a-z]\z/) }

    [*'A'..'Z'].map { |letter| { value: letter, included?: alpha_set.include?(letter) } }
  end

  def resolve_letter_context
    load_segment_counts
    @letter_options = letter_options_for_practice
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

    scoped = base_scope.with_practice(current_user.practice_id).with_last_visit

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

    return '#' if @has_non_alpha_patients

    first_included = @letter_options&.find { |opt| opt[:included?] }
    first_included ? first_included[:value] : 'A'
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

  def patient_params
    params.require(:patient).permit(:uid, :firstname, :lastname, :fullname, :date_of_birth, :past_illnesses, :surgeries, :medications,
                                    :drugs_use, :cigarettes_per_day, :drinks_per_day, :family_diseases, :emergency_telephone, :email, :telephone, :mobile, :address, :allergies, :practice_id,
                                    :profile_picture, :remove_profile_picture)
  end
end
