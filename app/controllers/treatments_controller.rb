class TreatmentsController < ApplicationController
  before_filter :require_user
  
  def index
    @treatments = Treatment.mine.order("name")
  end

  def show
  	@treatment = Treatment.mine.find(params[:id])
  	
  	if @treatment.missing_info?
  	  redirect_to edit_treatment_path(@treatment)
  	else 
  	  respond_to do |format|
  	    format.html # show.html.erb
  	  end
  	end
  end

  def new
    @treatment = Treatment.new
  end

  def edit
    @treatment = Treatment.mine.find(params[:id])
  end

  def create
    @treatment = Treatment.new(params[:treatment])

    respond_to do |format|
      if @treatment.save
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
      format.html { redirect_to(treatments_url) }
    end
  end
  
  # This loads the list of treatments fom treatments.yml into the user's practice
  def predefined_treatments
    # Don't load if already done
    if Treatment.mine.count == 0 
      current_user.practice.populate_default_treatments 
      flash[:notice] = t(:predefined_treatments_created_success_message)
    end
    redirect_to treatments_url
  end

end
