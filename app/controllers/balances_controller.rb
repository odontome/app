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
    # don't know how to handle errors here, I guess they go in the create.js.erb
    @balance.save
    
    respond_with(@balance)
  end

end
