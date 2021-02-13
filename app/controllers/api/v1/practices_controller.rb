class Api::V1::PracticesController < Api::V1::BaseController
  before_action :find_practice, only: [:show]

  def show
    respond_with(@practice, only: %i[currency_unit locale name timezone created_at])
  end

  private

  def find_practice
    @practice = Practice.find(@current_user.user.practice.id)
  rescue ActiveRecord::RecordNotFound
    error = { error: 'The practice you were looking for could not be found.' }
    respond_with(error, status: 404)
  end
end
