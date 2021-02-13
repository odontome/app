class Api::V1::BalancesController < Api::V1::BaseController
  before_action :find_balance, only: [:show]

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

    respond_with(Balance.find_between(starts_at, ends_at, @current_user.user.practice_id))
  end

  def show
    respond_with(@balance)
  end

  def create
    balance = Balance.create(params[:balance])

    if balance.valid?
      respond_with(balance, location: api_v1_balance_path(balance))
    else
      respond_with(balance)
    end
  end

  def show
    respond_with(@balance)
  end

  def update
    @balance.update_attributes(params[:balance])
    respond_with(@balance)
  end

  # def destroy
  #   @balance.destroy
  #   respond_with(@balance)
  # end

  private

  def find_balance
    @balance = Balance.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    error = { error: 'The balance you were looking for could not be found.' }
    respond_with(error, status: 404)
  end
end
