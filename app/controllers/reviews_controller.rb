# frozen_string_literal: true

class ReviewsController < ApplicationController
  # filters
  before_action :require_user, except: %i[new create]

  def index
    reviews_per_page = 20
    @current_page = 0
    @reviews = Review.with_practice(current_user.practice_id).limit(reviews_per_page)

    if params[:score].present?
      @reviews = @reviews.where(score: params[:score].to_i)
    end

    if params[:page].nil?
      @reviews = @reviews.offset(0)
    else
      @reviews = @reviews.offset(params[:page].to_i * reviews_per_page)
      @current_page = params[:page].to_i
    end

    # increment the current page count
    @current_page += 1
    # calculate if we need to load more reviews
    @should_display_load_more = Review.with_practice(current_user.practice_id).count >= (@current_page * reviews_per_page)

    respond_to do |format|
      format.html # index.html
      format.js
      format.json { render json: @reviews }
    end
  end

  def new
    @review = Review.new

    begin
      # check that this appointment is reviewable
      deciphered_appointment_id = Cipher.decode params[:appointment_id]
      @appointment = Appointment.where(id: deciphered_appointment_id).includes(:doctor, datebook: [:practice]).first

      if Review.where(appointment_id: deciphered_appointment_id).exists?
        # do nothing, handle this in the view
      else
        @review.score = params[:score]
        @review.appointment_id = params[:appointment_id]
      end
    rescue Exception
      redirect_to 'https://www.odonto.me'
      return
    end

    respond_to do |format|
      format.html { render layout: 'simple' }
      format.json { render json: @reviews }
    end
  end

  def create
    @review = Review.new(review_params)
    @review.appointment_id = Cipher.decode(review_params[:appointment_id])

    respond_to do |format|
      if @review.save
        # email the admin about this review
        PracticeMailer.new_review_notification(@review).deliver_now
        format.js {} # create.js.erb
      else
        format.js do
          render_ujs_error(@review, I18n.t(:review_created_error_message))
        end
      end
    end
  end

  private

  def review_params
    params.require(:review).permit(:appointment_id, :score, :comment)
  end
end
