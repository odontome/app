class TreatmentsController < ApplicationController
  before_filter :require_user
  
  def index
    @treatments = Treatment.mine.order("name")
  end

  def show
    @treatment = Treatment.mine.find(params[:id])
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
        format.html { redirect_to(treatments_url, :notice => _('The new treatment was successfully created in your practice.')) }
      else
        format.html { render :action => "new" }
      end
    end
  end

  def update
    @treatment = Treatment.mine.find(params[:id])

    respond_to do |format|
      if @treatment.update_attributes(params[:treatment])
        format.html { redirect_to(treatments_url, :notice => _('Your practice\'s treatment was successfully updated.')) }
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

end
