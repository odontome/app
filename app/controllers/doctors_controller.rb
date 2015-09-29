class DoctorsController < ApplicationController
  # filters
  before_filter :require_user, :except => :appointments

  # provides
  respond_to :ics, :only => [:appointments]

  def index
    @doctors = Doctor.mine

    # track this event
    MIXPANEL_CLIENT.track(@current_user.email, 'Viewing all doctors profiles')
  end

  def show
    @doctor = Doctor.mine.find(params[:id])
    @appointments = @doctor.appointments.joins(:patient).where("starts_at > ?", Date.today).order("starts_at desc")

    # track this event
    MIXPANEL_CLIENT.track(@current_user.email, 'Viewing a doctor profile', {
      'Doctor' => @doctor.fullname,
      'Color' => @doctor.color
    })
  end

  def new
    @doctor = Doctor.new

    # track this event
    MIXPANEL_CLIENT.track(@current_user.email, 'Creating a doctor profile')
  end

  def edit
    @doctor = Doctor.mine.find(params[:id])

    # track this event
    MIXPANEL_CLIENT.track(@current_user.email, 'Modifying a doctor profile')
  end

  def create
    @doctor = Doctor.new(params[:doctor])

    respond_to do |format|
      if @doctor.save
        # track the creation of a complete patient profile
        MIXPANEL_CLIENT.track(@current_user.email, 'Compleated a doctor profile')

        format.html { redirect_to(doctors_url, :notice => t(:doctor_created_success_message))}
      else
        format.html { render :action => "new" }
      end
    end
  end

  def update
    @doctor = Doctor.mine.find(params[:id])

    respond_to do |format|
      if @doctor.update_attributes(params[:doctor])
        # track this event
        MIXPANEL_CLIENT.track(@current_user.email, 'Modified a doctor profile')

        format.html { redirect_to(doctors_url, :notice => t(:doctor_updated_success_message)) }
      else
        format.html { render :action => "edit" }
      end
    end
  end

  def destroy
    @doctor = Doctor.mine.find(params[:id])

    # Check if this doctor can be deleted, otherwise toggle his validness
    if @doctor.is_deleteable
      @doctor.destroy

      # track this event
      MIXPANEL_CLIENT.track(@current_user.email, 'Deleted a doctor profile')
    else
      @doctor.is_active = !@doctor.is_active
      @doctor.save

      # track this event
      MIXPANEL_CLIENT.track(@current_user.email, 'Toggled a doctor profile', {
          "Is Active?" => @doctor.is_active
      })
    end

    respond_to do |format|
      format.html { redirect_to(doctors_url) }
    end
  end

  def appointments
    doctor_id_deciphered = Cipher.decode(params[:doctor_id])
    @doctor = Doctor.find_by id: doctor_id_deciphered, is_active: true

    start_of_week = Date.today.at_beginning_of_week.to_time.to_i
    end_of_week = start_of_week + 2.weeks

    @appointments = @doctor.appointments.find_between(start_of_week, end_of_week).includes(:patient)

    # track this event
    MIXPANEL_CLIENT.track(@doctor.email, 'Requested calendar subscription', {
        'Number of appointments' => @appointments.size,
        'Practice' => @doctor.practice.name
    })

    respond_with(@appointments)
  end

end
