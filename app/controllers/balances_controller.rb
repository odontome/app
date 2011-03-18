class BalancesController < ApplicationController
  before_filter :require_user
  
  # provides
  respond_to :html, :js
  
  def index
    @balances = Balance.where("patient_id = ?", params[:patient_id])
    render :layout => nil
  end

  def create
    @balance = Balance.new(params[:balance])
    @balance.patient_id = params[:patient_id] #FIXME yeah this sucks
    
    respond_to do |format|
      if @balance.save
          format.js  { } #create.js.erb
      else
          format.js  {
            render_ujs_error(@balance, _("There was an error creating this entry"))
          }
      end
    end
  end

end
