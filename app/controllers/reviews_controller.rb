class ReviewsController < ApplicationController
  # filters
  before_filter :require_user, :except => [:new, :create]

  # provides
  respond_to :html, :js

  def index
    @reviews = Review.all
    respond_with(@reviews)
  end

  def new
    @review = Review.new

    begin
      # check that this appointment is reviewable
      deciphered_appointment_id = Cipher.decode params[:appointment_id]
      appointment = Appointment.find(deciphered_appointment_id)

      if Review.where(appointment_id: deciphered_appointment_id).count != 0

      end

      @review.score = params[:score]
      @review.appointment_id = params[:appointment_id]

    rescue Exception
      redirect_to "http://www.odonto.me"
      return
    end

    respond_with(@review, layout: "simple")
  end

  def create
    @review = Review.new(review_params)
    @review.appointment_id = Cipher.decode(review_params[:appointment_id])

    respond_to do |format|
      if @review.save
          format.js  { } #create.js.erb
      else
          format.js  {
            render_ujs_error(@review, I18n.t(:review_created_error_message))
          }
      end
    end

  end

  private

    def review_params
      params.require(:review).permit(:appointment_id, :score, :comment)
    end
end
