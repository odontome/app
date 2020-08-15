class ReviewsController < ApplicationController
  # filters
  before_action :require_user, :except => [:new, :create]

  # provides
  respond_to :html, :js

  def index
    reviews_per_page = 15
    @current_page = 0
    @reviews = Review.mine.limit(reviews_per_page)

    if params[:page].nil?
      @reviews = @reviews.offset(0)
    else
      @reviews = @reviews.offset(params[:page].to_i * reviews_per_page)
      @current_page = params[:page].to_i
    end

    # increment the current page count
    @current_page = @current_page + 1
    # calculate if we need to load more reviews
    @should_display_load_more = Review.mine.count >= (@current_page * reviews_per_page)

    respond_with(@reviews)
  end

  def new
    @review = Review.new

    begin
      # check that this appointment is reviewable
      deciphered_appointment_id = Cipher.decode params[:appointment_id]
      @appointment = Appointment.where(id: deciphered_appointment_id).includes(:doctor, :datebook => [:practice]).first

      if Review.where(appointment_id: deciphered_appointment_id).exists?
        # do nothing, handle this in the view
      else
        @review.score = params[:score]
        @review.appointment_id = params[:appointment_id]
      end

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
        # email the admin about this review
        PracticeMailer.new_review_notification(@review).deliver_now
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
