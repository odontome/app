class Api::V1::NotesController < Api::V1::BaseController
  
  before_action :find_noteable
  before_action :find_note, :only => [:show, :update]
  
  def index
    respond_with(@noteable.notes, :only => [:created_at, :id, :notes])
  end
  
  def show
    respond_with(@note, :only => [:created_at, :id, :notes])
  end
  
  def create
    note = @noteable.notes.build(params[:note])
    
    if note.valid?
      respond_with(@noteable, note)
    else
      respond_with(note)
  	end 
  end
  
  def update
  	@note.update_attributes(params[:note])
		respond_with(@note)
  end
    
  private

  def find_note
  	@note = @noteable.notes.find(params[:id])
  	rescue ActiveRecord::RecordNotFound
  		error = { :error => "The note you were looking for could not be found."}
  		respond_with(error, :status => 404)
  end

  def find_noteable
  	@noteable = nil
    params.each do |name, value|
      if name =~ /(.+)_id$/
        @noteable = $1.classify.constantize.find(value)
      end
    end
  end
  
end