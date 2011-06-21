class <%= class_name.pluralize %>Controller < ApplicationController
  respond_to :html,:json
  
  protect_from_forgery :except => [:post_data]
  
  # Don't forget to edit routes if you're using RESTful routing
  # 
  #resources :<%=plural_name%>,:only => [:index] do
  #   collection do
  #     post "post_data"
  #   end
  # end

  def post_data
    message=""
    <%= model_name %>_params = { <%= columns.collect { |x| ":" + x + " => params[:" + x + "],"}.join.chomp(",") %> }
    case params[:oper]
    when 'add'
      if params["id"] == "_empty"
        <%= model_name %> = <%= camel %>.create(<%= model_name %>_params)
        message << ('add ok') if <%= model_name %>.errors.empty?
      end
      
    when 'edit'
      <%= model_name %> = <%= camel %>.find(params[:id])
      message << ('update ok') if <%= model_name %>.update_attributes(<%= model_name %>_params)
    when 'del'
      <%= camel %>.destroy_all(:id => params[:id].split(","))
      message <<  ('del ok')
    when 'sort'
      <%=plural_name%> = <%= camel %>.all
      <%=plural_name%>.each do |<%= model_name %>|
        <%= model_name %>.position = params['ids'].index(<%= model_name %>.id.to_s) + 1 if params['ids'].index(<%= model_name %>.id.to_s) 
        <%= model_name %>.save
      end
      message << "sort ak"
    else
      message <<  ('unknown action')
    end
    
    unless (<%= model_name %> && <%= model_name %>.errors).blank?  
      <%= model_name %>.errors.entries.each do |error|
        message << "<strong>#{<%= camel %>.human_attribute_name(error[0])}</strong> : #{error[1]}<br/>"
      end
      render :json =>[false,message]
    else
      render :json => [true,message] 
    end
  end
  
  
  def index
    index_columns ||= [<%= columns.collect { |x| ":" + x + "," }.join.chomp(',') %>]
    current_page = params[:page] ? params[:page].to_i : 1
    rows_per_page = params[:rows] ? params[:rows].to_i : 10

    conditions={:page => current_page, :per_page => rows_per_page}
    conditions[:order] = params["sidx"] + " " + params["sord"] unless (params[:sidx].blank? || params[:sord].blank?)
    
    if params[:_search] == "true"
      conditions[:conditions]=filter_by_conditions(index_columns)
    end
    
    @<%= plural_name %>=<%= camel %>.paginate(conditions)
    total_entries=@<%= plural_name %>.total_entries
    
    respond_with(@<%= plural_name %>) do |format|
      format.json { render :json => @<%= plural_name %>.to_jqgrid_json(index_columns, current_page, rows_per_page, total_entries)}  
    end
  end

end