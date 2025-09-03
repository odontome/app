# frozen_string_literal: true

module Api::Mcp
  class DatabooksController < BaseController
    before_action :ensure_practice_exists
    before_action :set_datebook, only: [:show, :update, :destroy]
    
    def index
      @datebooks = practice_datebooks.order('name')
      
      render_success(@datebooks.as_json(include: { appointments: { include: [:doctor, :patient] } }))
    end
    
    def show
      render_success(@datebook.as_json(include: { appointments: { include: [:doctor, :patient] } }))
    end
    
    def create
      @datebook = practice_datebooks.build(datebook_params)
      @datebook.practice_id = current_user.practice_id
      
      if @datebook.save
        render_success(@datebook, status: :created)
      else
        render_validation_errors(@datebook)
      end
    end
    
    def update
      if @datebook.update(datebook_params)
        render_success(@datebook)
      else
        render_validation_errors(@datebook)
      end
    end
    
    def destroy
      if @datebook.is_deleteable
        @datebook.destroy
        head :no_content
      else
        render json: { error: 'Cannot delete datebook with existing appointments' }, 
               status: :unprocessable_entity
      end
    end
    
    private
    
    def practice_datebooks
      Datebook.with_practice(current_user.practice_id)
    end
    
    def set_datebook
      @datebook = practice_datebooks.find_by(id: params[:id])
      
      unless @datebook
        render_not_found('Datebook not found')
        return false
      end
    end
    
    def datebook_params
      params.require(:datebook).permit(:name, :starts_at, :ends_at)
    end
  end
end