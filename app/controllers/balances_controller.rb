class BalancesController < ApplicationController
  before_filter :require_user
  
  def index
    @balance = Balance.where("patient_id = ?", params[:patient_id]).order("created_at desc")
    render :layout => nil
  end

  def create
    @balance = Balance.new(params[:balance])
    @balance.patient_id = params[:patient_id] #FIXME yeah this sucks
    
    respond_to do |format|
      if @balance.save
        #format.html { redirect_to(doctors_url, :notice => _('Doctor was successfully created.')) }
      else
        #format.html { render :action => "new" }
      end
    end
  end

end
