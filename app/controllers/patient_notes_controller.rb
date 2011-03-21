class PatientNotesController < ApplicationController
  before_filter :require_user
  
  # provides
  respond_to :js

  def create
    @note = PatientNote.new(params[:patient_note])
    @note.patient_id = params[:patient_id] #FIXME yeah this sucks
    
    respond_to do |format|
      if @note.save
          format.js  { } #create.js.erb
      else
          format.js  {
            render_ujs_error(@note, _("There was an error creating this note"))
          }
      end
    end
  end

  def destroy
    @note = PatientNote.find_by_id_and_patient_id(params[:id],params[:patient_id])
    @note.destroy

    respond_to do |format|
      format.js { }
    end
  end

end
