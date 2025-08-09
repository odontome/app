# frozen_string_literal: true

class PracticesController < ApplicationController
  before_action :require_user, only: %i[index destroy edit settings show close]
  before_action :require_no_user, only: %i[new create]
  before_action :require_superadmin, only: %i[index destroy edit]
  before_action :require_practice_admin, only: %i[show settings balance update close]
  skip_before_action :check_subscription_status

  def index
    @practices = Practice.all
  end

  def show
    @practice = current_user.practice

    # Weekly analytics (Mon-Sun) for charts
    @week_start = DateTime.now.beginning_of_week
    @week_end = DateTime.now.end_of_week
  @prev_week_start = (@week_start - 1.week).beginning_of_week
  @prev_week_end = (@week_end - 1.week).end_of_week

    # Top doctors by unique patients this week (limit 10)
    top_doctors_scope = Appointment
                          .joins(:doctor)
                          .where('appointments.starts_at >= ? AND appointments.starts_at <= ?', @week_start, @week_end)
                          .where(doctors: { practice_id: current_user.practice_id })
                          .group('doctors.id', 'doctors.firstname', 'doctors.lastname')
                          .select('doctors.id, doctors.firstname, doctors.lastname, COUNT(DISTINCT appointments.patient_id) AS patients_count')
                          .order('patients_count DESC')
                          .limit(10)
    @weekly_top_doctors_names = top_doctors_scope.map { |d| [d.firstname, d.lastname].join(' ') }
    @weekly_top_doctors_values = top_doctors_scope.map { |d| d.read_attribute(:patients_count).to_i }

    # Hours worked by doctors this week (sum of appointment durations, limit 10)
    hours_sql = 'SUM(EXTRACT(EPOCH FROM (appointments.ends_at - appointments.starts_at)))/3600.0 AS hours'
    hours_scope = Appointment
                    .joins(:doctor)
                    .where('appointments.starts_at >= ? AND appointments.starts_at <= ?', @week_start, @week_end)
                    .where(doctors: { practice_id: current_user.practice_id })
                    .group('doctors.id', 'doctors.firstname', 'doctors.lastname')
                    .select("doctors.id, doctors.firstname, doctors.lastname, #{hours_sql}")
                    .order('hours DESC')
                    .limit(10)
    @weekly_hours_doctor_names = hours_scope.map { |d| [d.firstname, d.lastname].join(' ') }
    @weekly_hours_doctor_values = hours_scope.map { |d| d.read_attribute(:hours).to_f.round(1) }

    # Most recurring patients this week (by appointment count, limit 10)
    recurring_scope = Appointment
                        .joins(:patient)
                        .where('appointments.starts_at >= ? AND appointments.starts_at <= ?', @week_start, @week_end)
                        .where(patients: { practice_id: current_user.practice_id })
                        .group('patients.id', 'patients.firstname', 'patients.lastname')
                        .select('patients.id, patients.firstname, patients.lastname, COUNT(*) AS appointments_count')
                        .order('appointments_count DESC')
                        .limit(10)
    @weekly_recurring_patient_names = recurring_scope.map { |p| [p.firstname, p.lastname].join(' ') }
    @weekly_recurring_patient_values = recurring_scope.map { |p| p.read_attribute(:appointments_count).to_i }

    # Average time gap (minutes) between consecutive appointments per doctor this week (limit 10)
    appts_for_gap = Appointment
                      .joins(:doctor)
                      .where('appointments.starts_at >= ? AND appointments.starts_at <= ?', @week_start, @week_end)
                      .where(doctors: { practice_id: current_user.practice_id })
                      .select('appointments.id, appointments.starts_at, appointments.ends_at, appointments.doctor_id, doctors.firstname, doctors.lastname')
                      .order('appointments.doctor_id ASC, appointments.starts_at ASC')

    gaps_by_doctor = {}
    names_by_doctor = {}
    appts_for_gap.group_by(&:doctor_id).each do |doctor_id, appts|
      prev_end = nil
      gaps = []
      appts.each do |a|
        if prev_end
          gap = ((a.starts_at - prev_end) / 60.0).to_f
          gaps << gap if gap.positive?
        end
        prev_end = a.ends_at
      end
      next if gaps.empty?
      gaps_by_doctor[doctor_id] = (gaps.sum / gaps.size).round(1)
      doc = appts.first
      names_by_doctor[doctor_id] = [doc.firstname, doc.lastname].join(' ')
    end

    avg_gap_sorted = gaps_by_doctor.sort_by { |_id, avg| avg }
    avg_gap_sorted = avg_gap_sorted.first(10)
    @weekly_avg_gap_doctor_names = avg_gap_sorted.map { |id, _avg| names_by_doctor[id] }
    @weekly_avg_gap_doctor_values = avg_gap_sorted.map { |_id, avg| avg }

    # Appointments per day this week (Mon..Sun)
    appts_by_day = Appointment
                     .joins(:patient)
                     .where(patients: { practice_id: current_user.practice_id })
                     .where('appointments.starts_at >= ? AND appointments.starts_at <= ?', @week_start, @week_end)
                     .group("DATE(appointments.starts_at)")
                     .order('DATE(appointments.starts_at) ASC')
                     .count
    # Normalize to whole week so missing days appear as zero
    @weekly_days_labels = []
    @weekly_appointments_per_day = []
    (@week_start.to_date..@week_end.to_date).each do |date|
      @weekly_days_labels << date.strftime('%a %d')
      @weekly_appointments_per_day << (appts_by_day[date] || 0)
    end

    # New vs Returning patients seen this week (based on patient created_at)
    uniq_patients_this_week = Appointment
                                .joins(:patient)
                                .where('appointments.starts_at >= ? AND appointments.starts_at <= ?', @week_start, @week_end)
                                .where(patients: { practice_id: current_user.practice_id })
                                .select('DISTINCT patients.id, patients.created_at')
    new_count = 0
    returning_count = 0
    uniq_patients_this_week.each do |p|
      if p.created_at && p.created_at >= @week_start && p.created_at <= @week_end
        new_count += 1
      else
        returning_count += 1
      end
    end
    @weekly_new_vs_returning = [new_count, returning_count]

    # New patients per day this week (for KPI sparkline)
    new_by_day = Patient
                   .where(practice_id: current_user.practice_id)
                   .where('created_at >= ? AND created_at <= ?', @week_start, @week_end)
                   .group('DATE(created_at)')
                   .order('DATE(created_at) ASC')
                   .count
    @weekly_new_patients_per_day = []
    (@week_start.to_date..@week_end.to_date).each do |date|
      @weekly_new_patients_per_day << (new_by_day[date] || 0)
    end

    # Revenue per day this week
    revenue_by_day = Balance
                       .joins('LEFT OUTER JOIN patients ON balances.patient_id = patients.id')
                       .where('patients.practice_id = ?', current_user.practice_id)
                       .where('balances.created_at >= ? AND balances.created_at <= ?', @week_start, @week_end)
                       .group('DATE(balances.created_at)')
                       .order('DATE(balances.created_at) ASC')
                       .sum(:amount)
    @weekly_revenue_per_day = []
    (@week_start.to_date..@week_end.to_date).each do |date|
      @weekly_revenue_per_day << (revenue_by_day[date] || 0)
    end

  # KPI metrics
  @kpi_appointments_this_week = Appointment
                  .joins(:patient)
                  .where(patients: { practice_id: current_user.practice_id })
                  .where('appointments.starts_at >= ? AND appointments.starts_at <= ?', @week_start, @week_end)
                  .count
  prev_appts = Appointment
           .joins(:patient)
           .where(patients: { practice_id: current_user.practice_id })
           .where('appointments.starts_at >= ? AND appointments.starts_at <= ?', @prev_week_start, @prev_week_end)
           .count
  @kpi_appointments_delta = prev_appts.zero? ? 100.0 : (((@kpi_appointments_this_week - prev_appts) / prev_appts.to_f) * 100.0).round(1)

  @kpi_revenue_this_week = Balance
                 .joins('LEFT OUTER JOIN patients ON balances.patient_id = patients.id')
                 .where('patients.practice_id = ?', current_user.practice_id)
                 .where('balances.created_at >= ? AND balances.created_at <= ?', @week_start, @week_end)
                 .sum(:amount)
  prev_rev = Balance
         .joins('LEFT OUTER JOIN patients ON balances.patient_id = patients.id')
         .where('patients.practice_id = ?', current_user.practice_id)
         .where('balances.created_at >= ? AND balances.created_at <= ?', @prev_week_start, @prev_week_end)
         .sum(:amount)
  @kpi_revenue_delta = prev_rev.zero? ? 100.0 : (((@kpi_revenue_this_week - prev_rev) / prev_rev.to_f) * 100.0).round(1)

  @kpi_new_patients = Patient
              .where(practice_id: current_user.practice_id)
              .where('created_at >= ? AND created_at <= ?', @week_start, @week_end)
              .count
  prev_new = Patient
         .where(practice_id: current_user.practice_id)
         .where('created_at >= ? AND created_at <= ?', @prev_week_start, @prev_week_end)
         .count
  @kpi_new_patients_delta = prev_new.zero? ? 100.0 : (((@kpi_new_patients - prev_new) / prev_new.to_f) * 100.0).round(1)

    # Reviews KPI (this week and delta vs last week)
    @kpi_reviews_this_week = Review
                               .joins(appointment: { datebook: :practice })
                               .where('practices.id = ?', current_user.practice_id)
                               .where('reviews.created_at >= ? AND reviews.created_at <= ?', @week_start, @week_end)
                               .count
    prev_reviews = Review
                     .joins(appointment: { datebook: :practice })
                     .where('practices.id = ?', current_user.practice_id)
                     .where('reviews.created_at >= ? AND reviews.created_at <= ?', @prev_week_start, @prev_week_end)
                     .count
    @kpi_reviews_delta = prev_reviews.zero? ? 100.0 : (((@kpi_reviews_this_week - prev_reviews) / prev_reviews.to_f) * 100.0).round(1)

    # Reviews per day for sparkline
    reviews_by_day = Review
                       .joins(appointment: { datebook: :practice })
                       .where('practices.id = ?', current_user.practice_id)
                       .where('reviews.created_at >= ? AND reviews.created_at <= ?', @week_start, @week_end)
                       .group('DATE(reviews.created_at)')
                       .order('DATE(reviews.created_at) ASC')
                       .count
    @weekly_reviews_per_day = []
    (@week_start.to_date..@week_end.to_date).each do |date|
      @weekly_reviews_per_day << (reviews_by_day[date] || 0)
    end
  end

  def new
    @practice = Practice.new
    @practice.users.build
    @user = User.new

    render layout: 'user_sessions'
  end

  def edit
    @practice = current_user.practice
  end

  def create
    @practice = Practice.new(practice_params)

    respond_to do |format|
      if @practice.save
        # find the previously created user
        new_user = @practice.users.first

        # extract the user password from the request
        user_password = params[:practice][:users_attributes]['0']['password']
        # authenticate the user using shared method
        authenticate_and_set_session(new_user, user_password)

        PracticeMailer.welcome_email(@practice).deliver_now
        format.html { redirect_to(practice_path) }
      else
        format.html { render action: 'new', as: :signup, layout: 'user_sessions' }
      end
    end
  end

  def update
    @practice = current_user.practice
    @subscription = @practice.subscription
    
    respond_to do |format|
      if @practice.update(practice_params)
        format.html { redirect_to(practice_settings_url, notice: t(:practice_updated_success_message)) }
      else
        format.html { render action: 'settings' }
      end
    end
  end

  def cancel
    # Intentionally left blank
  end

  def close
    @practice = current_user.practice
    @practice.set_as_cancelled
    if @practice.save
      session.clear
      flash.discard
      redirect_to signin_url, notice: I18n.t(:practice_close_success_message)
    else
      @practice.errors[:base] << I18n.t(:practice_close_error_message)
      redirect_to practice_settings_url
    end
  end

  def destroy
    @practice = Practice.find(params[:id])
    @practice.destroy

    respond_to do |format|
      format.html { redirect_to(practices_url) }
      format.xml  { head :ok }
    end
  end

  def settings
    @practice = current_user.practice
    @subscription = @practice.subscription
  end

  def balance
    starts_at = if params[:created_at]
                  DateTime.parse params[:created_at]
                else
                  DateTime.now
                end

    starts_at = starts_at.at_beginning_of_day
    ends_at = starts_at + 24.hours

    @selected_date = starts_at.strftime('%A, %d %B %y')
    @min_date = @current_user.practice.created_at.strftime('%Y-%m-%d')
    @max_date = 1.day.from_now.strftime('%Y-%m-%d')

    @balances = Balance.find_between starts_at, ends_at, @current_user.practice_id
    @total = @balances.sum(:amount)

    respond_to do |format|
      format.html
      format.csv do
        headers['Content-Type'] = 'text/csv'
        headers['Content-disposition'] = "attachment; filename=#{starts_at}.csv"
      end
    end
  end

  private

  def practice_params
    params.require(:practice).permit(:name, :locale, :timezone, :currency_unit, :email, users_attributes: [:firstname, :lastname, :email, :password, :password_confirmation])
  end
end
