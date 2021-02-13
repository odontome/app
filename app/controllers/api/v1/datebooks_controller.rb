class Api::V1::DatebooksController < Api::V1::BaseController
  before_action :find_datebook, only: [:show]

  def index
    datebooks = Datebook.with_practice(current_user.practice_id)
                        .select('datebooks.id, datebooks.name, datebooks.updated_at, count(appointments.id) as appointments_count')
                        .joins('left outer join appointments on appointments.datebook_id = datebooks.id')
                        .group('datebooks.id')
                        .order('name')

    respond_with(datebooks)
  end

  def show
    respond_with(@datebook)
  end

  def create
    datebook = Datebook.create(params[:datebook])

    if datebook.valid?
      respond_with(datebook, location: api_v1_datebook_path(datebook))
    else
      respond_with(datebook)
    end
  end

  def show
    respond_with(@datebook)
  end

  def update
    @datebook.update_attributes(params[:datebook])
    respond_with(@datebook)
  end

  # def destroy
  #   @datebook.destroy
  #   respond_with(@datebook)
  # end

  private

  def find_datebook
    @datebook = Datebook.with_practice(current_user.practice_id).find(params[:id])
  rescue ActiveRecord::RecordNotFound
    error = { error: 'The datebook you were looking for could not be found.' }
    respond_with(error, status: 404)
  end
end
