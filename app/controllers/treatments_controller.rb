class TreatmentsController < ApplicationController
  before_action :require_user

  def index
    @treatments = Treatment.mine.order("name")

    # track this event
    MIXPANEL_CLIENT.track(@current_user.email, 'Viewing all treatments')
  end

  def new
    @treatment = Treatment.new

    # track this event
    MIXPANEL_CLIENT.track(@current_user.email, 'Creating a new treatment')
  end

  def edit
    @treatment = Treatment.mine.find(params[:id])

    # track this event
    MIXPANEL_CLIENT.track(@current_user.email, 'Modifying a treatment')
  end

  def create
    @treatment = Treatment.new(params[:treatment])

    respond_to do |format|
      if @treatment.save
        # track this event
        MIXPANEL_CLIENT.track(@current_user.email, 'Created a treatment')

        format.html { redirect_to(treatments_url, :notice => t(:treatments_created_success_message)) }
      else
        format.html { render :action => "new" }
      end
    end
  end

  def update
    @treatment = Treatment.mine.find(params[:id])

    respond_to do |format|
      if @treatment.update_attributes(params[:treatment])
        # track this event
        MIXPANEL_CLIENT.track(@current_user.email, 'Modified a treatment')

        format.html { redirect_to(treatments_url, :notice => t(:treatments_updated_success_message)) }
      else
        format.html { render :action => "edit" }
      end
    end
  end

  def destroy
    @treatment = Treatment.mine.find(params[:id])
    @treatment.destroy

    respond_to do |format|
      # track this event
      MIXPANEL_CLIENT.track(@current_user.email, 'Deleted a treatment', {
          "Name" => @treatment.name
      })

      format.html { redirect_to(treatments_url) }
    end
  end

  # This loads the list of treatments fom treatments.yml into the user's practice
  def predefined_treatments
    # Don't load if already done
    if Treatment.mine.count == 0
      current_user.practice.populate_default_treatments
      flash[:notice] = t(:predefined_treatments_created_success_message)

      # track this event
      MIXPANEL_CLIENT.track(@current_user.email, 'Created the predefined treatments')
    end
    redirect_to treatments_url
  end

end
