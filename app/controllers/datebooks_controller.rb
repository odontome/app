class DatebooksController < ApplicationController
  before_filter :require_user
  before_filter :require_practice_admin, :except => [:show]

  def index
  	# this same variable is already defined in the
    # application controller. Maybe we should think of
    # a way to remove it from there
    @datebooks = Datebook.mine
    .select('datebooks.id, datebooks.name, datebooks.updated_at, datebooks.starts_at, datebooks.ends_at, count(appointments.id) as appointments_count')
    .joins('left outer join appointments on appointments.datebook_id = datebooks.id')
    .group('datebooks.id')
    .order('datebooks.created_at')

    # track this event
    MIXPANEL_CLIENT.track(@current_user.email, 'Viewing all datebooks')
  end

  def show
    @doctors = Doctor.mine.order("firstname")
    @filtered_by = params[:doctor_id] || nil
    @datebook = Datebook.mine.find params[:id]

    # store this variable in the session scope, the next time
    # so when the user clicks on the logo it will send him
    # to this datebook
    session[LAST_VISITED_DATEBOOK] = @datebook.id

    # Detect if this is coming from a mobile device
    @is_mobile = request.user_agent =~ /iPhone|webOS|Android/
  end

  def new
    @datebook = Datebook.new

    # track this event
    MIXPANEL_CLIENT.track(@current_user.email, 'Creating a new datebook')
  end

  def create
    @datebook = Datebook.new(params[:datebook])

    respond_to do |format|
      if @datebook.save
        # track this event
        MIXPANEL_CLIENT.track(@current_user.email, 'Completed a datebook')

        format.html { redirect_to(datebooks_url, :notice => t(:datebook_created_success_message))}
      else
        format.html { render :action => "new" }
      end
    end
  end

  def edit
    @datebook = Datebook.mine.find params[:id]

    # track this event
    MIXPANEL_CLIENT.track(@current_user.email, 'Modifying a datebook')
  end

  def update
    @datebook = Datebook.mine.find params[:id]

    respond_to do |format|
      if @datebook.update_attributes(params[:datebook])
        # track this event
        MIXPANEL_CLIENT.track(@current_user.email, 'Modified a datebook')

        format.html { redirect_to(datebooks_url, :notice => t(:datebook_updated_success_message)) }
      else
        format.html { render :action => "edit" }
      end
    end
  end

  def destroy
    @datebook = Datebook.mine.find params[:id]

    respond_to do |format|
      if (@datebook.destroy)
        # track this event
        MIXPANEL_CLIENT.track(@current_user.email, 'Deleted a datebook', {
          'Name' => @datebook.name
        })

        format.html { redirect_to(datebooks_url) }
      else
        format.html { redirect_to(datebooks_url, :error => I18n.t("errors.messages.has_appointments"))}
      end
    end
  end

end
