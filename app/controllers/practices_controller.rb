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

    # Delegated per-model analytics
    range = @week_start..@week_end
    prev_range = @prev_week_start..@prev_week_end

    appt_analytics = Analytics::AppointmentAnalytics.new(current_user.practice_id)
    patient_analytics = Analytics::PatientAnalytics.new(current_user.practice_id)
    balance_analytics = Analytics::BalanceAnalytics.new(current_user.practice_id)
    review_analytics = Analytics::ReviewAnalytics.new(current_user.practice_id)

    # Leaderboards and distributions
    @weekly_top_doctors_names, @weekly_top_doctors_values = appt_analytics.top_doctors_by_unique_patients(range, limit: 10)
    @weekly_hours_doctor_names, @weekly_hours_doctor_values = appt_analytics.hours_worked_by_doctor(range, limit: 10)
    @weekly_recurring_patient_names, @weekly_recurring_patient_values = appt_analytics.recurring_patients(range, limit: 10)
    @weekly_avg_gap_doctor_names, @weekly_avg_gap_doctor_values = appt_analytics.average_gap_minutes_by_doctor(range, limit: 10)

    # Time series
    @weekly_days_labels, @weekly_appointments_per_day = appt_analytics.appointments_per_day(range)
    @weekly_new_patients_per_day = patient_analytics.new_patients_per_day(range)
    @weekly_revenue_per_day = balance_analytics.revenue_per_day(range)
    @weekly_reviews_per_day = review_analytics.reviews_per_day(range)

    # Composition
    @weekly_new_vs_returning = appt_analytics.new_vs_returning(range)

    # KPIs and deltas
    @kpi_appointments_this_week = appt_analytics.count(range)
    prev_appts = appt_analytics.count(prev_range)
    @kpi_appointments_delta = prev_appts.zero? ? 100.0 : (((@kpi_appointments_this_week - prev_appts) / prev_appts.to_f) * 100.0).round(1)

    @kpi_revenue_this_week = balance_analytics.sum(range)
    prev_rev = balance_analytics.sum(prev_range)
    @kpi_revenue_delta = prev_rev.zero? ? 100.0 : (((@kpi_revenue_this_week - prev_rev) / prev_rev.to_f) * 100.0).round(1)

    @kpi_new_patients = patient_analytics.new_count(range)
    prev_new = patient_analytics.new_count(prev_range)
    @kpi_new_patients_delta = prev_new.zero? ? 100.0 : (((@kpi_new_patients - prev_new) / prev_new.to_f) * 100.0).round(1)

    @kpi_reviews_this_week = review_analytics.count(range)
    prev_reviews = review_analytics.count(prev_range)
    @kpi_reviews_delta = prev_reviews.zero? ? 100.0 : (((@kpi_reviews_this_week - prev_reviews) / prev_reviews.to_f) * 100.0).round(1)
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
