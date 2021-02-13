class Api::V1::AppointmentsController < Api::V1::BaseController
  before_action :find_datebook, only: [:index]
  before_action :find_appointment, only: %i[show update destroy]
  before_action :validate_date_range, only: [:index]

  def index
    case params[:from]
    when 'today'
      starts_at = DateTime.now.at_beginning_of_day
      ends_at = starts_at + 24.hours
    when 'week'
      starts_at = DateTime.now.at_beginning_of_week
      ends_at = starts_at + 7.days
    when 'month'
      starts_at = DateTime.now.at_beginning_of_month
      ends_at = starts_at + 31.days
    end

    respond_with(@datebook.appointments.find_between(starts_at, ends_at), methods: %w[doctor patient])
  end

  def show
    respond_with(@appointment, methods: %w[doctor patient])
  end

  def create
    appointment = Appointment.create(params[:appointment])

    if appointment.valid?
      respond_with(appointment, location: api_v1_appointment_path(appointment))
    else
      respond_with(appointment)
    end
  end

  def update
    @appointment.update_attributes(params[:appointment])
    respond_with(@appointment)
  end

  def destroy
    @appointment.destroy
    respond_with(@appointment)
  end

  private

  def find_datebook
    @datebook = Datebook.with_practice(current_user.practice_id).find(params[:datebook_id])
  rescue ActiveRecord::RecordNotFound
    error = { error: 'The datebook you were looking for could not be found.' }
    respond_with(error, status: 404)
  end

  def find_appointment
    @appointment = Appointment.with_practice(current_user.practice_id).find(params[:id])
  rescue ActiveRecord::RecordNotFound
    error = { error: 'The appointment you were looking for could not be found.' }
    respond_with(error, status: 404)
  end

  def validate_date_range
    unless %w[today week month].include? params[:from]
      error = { error: 'Invalid date range' }
      respond_with(error, status: 400)
    end
  end
end
