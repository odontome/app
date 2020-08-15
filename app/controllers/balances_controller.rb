class BalancesController < ApplicationController
  before_action :require_user

  # provides
  respond_to :html, :js, :csv

  def index
    @patient = Patient.mine.find(params[:patient_id])
    @balances = Balance.where("patient_id = ?", @patient.id)
    @total = Balance.where("patient_id = ?", params[:patient_id]).sum(:amount)
    @treatments = Treatment.mine.order("name")

    respond_to do |format|
      format.html
      format.csv {
        headers["Content-Type"] = "text/csv"
        headers["Content-disposition"] = "attachment; filename=#{@patient.fullname}.csv"
      }
    end
  end

  def create
    @balance = Balance.new(params[:balance])
    patient = Patient.mine.find(params[:patient_id])
    @balance.patient_id = patient.id

    respond_to do |format|
      if @balance.save
          @total = Balance.where("patient_id = ?", params[:patient_id]).sum(:amount)

          format.js  { } #create.js.erb
      else
          format.js  {
            render_ujs_error(@balance, I18n.t(:balance_created_error_message))
          }
      end
    end
  end

end
