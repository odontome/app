class NotesController < ApplicationController
  before_filter :require_user
  
  # provides
  respond_to :js

  def create
    @noteable = find_noteable
    @note = @noteable.notes.build(params[:note])
    
    respond_to do |format|
      if @note.save
          format.js  { } #create.js.erb
      else
          format.js  {
            render_ujs_error(@note, I18n.t(:note_created_error_message))
          }
      end
    end
  end

  def destroy
    @noteable = find_noteable
    @note = @noteable.notes.find(params[:id])
    @note.destroy

    respond_to do |format|
      format.js { }
    end
  end
  
  private
  
  def find_noteable
    params.each do |name, value|
      if name =~ /(.+)_id$/
        return $1.classify.constantize.find(value)
      end
    end
    nil
  end

end
