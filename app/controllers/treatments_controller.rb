# frozen_string_literal: true

class TreatmentsController < ApplicationController
  before_action :require_user
  around_action :lock_odontogram_configuration, only: %i[create update]

  def index
    @treatments = Treatment.catalogue_for(current_user.practice)
  end

  def new
    @treatment = Treatment.new
  end

  def show
    @treatment = find_treatment

    respond_to do |format|
      format.html
    end
  end

  def edit
    @treatment = find_treatment
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
    @treatment = find_treatment

    respond_to do |format|
      if @treatment.update(@treatment.builtin? ? treatment_params.slice(:price) : treatment_params)
        format.html { redirect_to(treatments_url, notice: t(:treatments_updated_success_message)) }
      else
        format.html { render action: 'edit' }
      end
    end
  end

  def destroy
    @treatment = find_treatment
    return head :forbidden if @treatment.builtin?
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

  def find_treatment
    records = current_user.practice.treatments
    return records.find(params[:id]) unless params[:id].to_s.start_with?('builtin-')

    category = params[:id].delete_prefix('builtin-')
    raise ActiveRecord::RecordNotFound unless OdontogramEntry::TREATMENT_CATEGORIES.include?(category)

    records.find_by(builtin_category: category) || records.build(builtin_category: category, name: category, odontogram_category: category)
  end

  def lock_odontogram_configuration
    if params[:id].to_s.start_with?('builtin-') || params[:treatment]&.key?(:odontogram_category)
      current_user.practice.with_lock do
        yield
      end
    else
      yield
    end
  end

  def treatment_params
    params.require(:treatment).permit(:name, :price, :odontogram_category)
  end
end
