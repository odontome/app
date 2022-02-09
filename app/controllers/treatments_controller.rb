# frozen_string_literal: true

class TreatmentsController < ApplicationController
  before_action :require_user

  def index
    @treatments = Treatment.with_practice(current_user.practice_id).order('name')
  end

  def new
    @treatment = Treatment.new
  end

  def edit
    @treatment = Treatment.with_practice(current_user.practice_id).find(params[:id])
  end

  def create
    @treatment = Treatment.new(treatment_params)
    @treatment.practice_id = current_user.practice_id

    respond_to do |format|
      if @treatment.save
        format.html { redirect_to(treatments_url, notice: t(:treatments_created_success_message)) }
      else
        format.html { render action: 'new' }
      end
    end
  end

  def update
    @treatment = Treatment.with_practice(current_user.practice_id).find(params[:id])

    respond_to do |format|
      if @treatment.update(treatment_params)
        format.html { redirect_to(treatments_url, notice: t(:treatments_updated_success_message)) }
      else
        format.html { render action: 'edit' }
      end
    end
  end

  def destroy
    @treatment = Treatment.with_practice(current_user.practice_id).find(params[:id])
    @treatment.destroy

    respond_to do |format|
      format.html { redirect_to(treatments_url) }
    end
  end

  # This loads the list of treatments fom treatments.yml into the user's practice
  def predefined_treatments
    # Don't load if already done
    if Treatment.with_practice(current_user.practice_id).count.zero?
      current_user.practice.populate_default_treatments
      flash[:notice] = t(:predefined_treatments_created_success_message)
    end
    redirect_to treatments_url
  end

  private

  def treatment_params
    params.require(:treatment).permit(:name, :price)
  end
end
