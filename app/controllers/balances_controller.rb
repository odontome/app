class BalancesController < ApplicationController
  before_filter :require_user

  # provides
  respond_to :html, :js, :csv

  def index
    @patient = Patient.mine.find(params[:patient_id])
    @balances = Balance.where("patient_id = ?", @patient.id)
    @total = Balance.where("patient_id = ?", params[:patient_id]).sum(:amount)
    @treatments = Treatment.mine.order("name")

    # track this event
    MIXPANEL_CLIENT.track(@current_user.email, 'View patient balance', {
      'Total' => @total
    })

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

          # track this event
          MIXPANEL_CLIENT.track(@current_user.email, 'Created a patient balance', {
            'Total' => @total
          })

          format.js  { } #create.js.erb
      else
          format.js  {
            render_ujs_error(@balance, I18n.t(:balance_created_error_message))
          }
      end
    end
  end

end
