class ReviewsController < ApplicationController
  # filters
  before_filter :require_user, :except => [:new, :create]

  # provides
  respond_to :html, :js

  def index
    @reviews = Review.mine

    # track the event in mixpanel
    MIXPANEL_CLIENT.track(@current_user.email, 'Viewing reviews')

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
        # track the event in mixpanel
        MIXPANEL_CLIENT.track(@appointment.id, 'Attempting a review', {
            'Patient' => @appointment.patient.fullname,
            'Doctor' => @appointment.doctor.fullname,
            'Practice' => @appointment.datebook.practice.name,
            'Score' => params[:score]
        })

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

        # track the event in mixpanel
        MIXPANEL_CLIENT.track(@review.appointment_id, 'Completed a review', {
          'Score' => @review.score
        })

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
