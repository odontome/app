class ReviewsController < ApplicationController
  # filters
  before_filter :require_user, :except => :show
  before_action :set_review, only: [:show, :edit, :update, :destroy]

  respond_to :html

  def index
    @reviews = Review.all
    respond_with(@reviews)
  end

  def new
    @review = Review.new
    respond_with(@review)
  end

  def create
    @review = Review.new(review_params)
    @review.save
    respond_with(@review)
  end

  private
    def set_review
      @review = Review.find(params[:id])
    end

    def review_params
      params.require(:review).permit(:appointment_id, :score, :comment)
    end
end
