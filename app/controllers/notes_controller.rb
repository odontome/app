# frozen_string_literal: true

class NotesController < ApplicationController
  before_action :require_user

  def create
    @noteable = find_noteable
    @note = @noteable.notes.build(note_params)
    @note.user_id = current_user.id

    respond_to do |format|
      if @note.save
        format.js {} # create.js.erb
      else
        format.js do
          render_ujs_error(@note, I18n.t(:note_created_error_message))
        end
      end
    end
  end

  def destroy
    @noteable = find_noteable
    @note = @noteable.notes.find(params[:id])
    @note.destroy

    respond_to do |format|
      format.js {}
    end
  end

  private

  def find_noteable
    params.each do |name, value|
      return Regexp.last_match(1).classify.constantize.find(value) if name =~ /(.+)_id$/
    end
    nil
  end

  def note_params
    params.require(:note).permit(:notes)
  end
end
