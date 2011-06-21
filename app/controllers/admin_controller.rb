class AdminController < ApplicationController

  before_filter :require_superadmin
  respond_to :html,:json

  def practices
    index_columns ||= [:id,:name,:locale,:timezone, :patients_count, :appointments_count, :doctors_count, :users_count]
    current_page = params[:page] ? params[:page].to_i : 1
    rows_per_page = params[:rows] ? params[:rows].to_i : 10

    conditions={:page => current_page, :per_page => rows_per_page}
    conditions[:order] = params["sidx"] + " " + params["sord"] unless (params[:sidx].blank? || params[:sord].blank?)
  
    if params[:_search] == "true"
      conditions[:conditions]=filter_by_conditions(index_columns)
    end
  
    @practices=Practice.paginate(conditions)
    total_entries=@practices.total_entries
  
    respond_with(@practices) do |format|
      format.json { render :json => @practices.to_jqgrid_json(index_columns, current_page, rows_per_page, total_entries)}  
    end
  end

end
