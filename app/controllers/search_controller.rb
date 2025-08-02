# frozen_string_literal: true

class SearchController < ApplicationController
  before_action :require_user

  def index
    @search_term = params[:term]
    @results = { patients: [], doctors: [], treatments: [] }

    if @search_term.present?
      begin
        @results[:patients] = Patient.search(@search_term).with_practice(current_user.practice_id)
      rescue => e
        Rails.logger.error "Patient search failed: #{e.message}"
        @results[:patients] = []
      end
      
      begin
        @results[:doctors] = Doctor.search(@search_term).with_practice(current_user.practice_id)
      rescue => e
        Rails.logger.error "Doctor search failed: #{e.message}"
        @results[:doctors] = []
      end
      
      begin
        @results[:treatments] = Treatment.search(@search_term).with_practice(current_user.practice_id)
      rescue => e
        Rails.logger.error "Treatment search failed: #{e.message}"
        @results[:treatments] = []
      end
    end

    respond_to do |format|
      format.html
      format.json { render json: @results }
    end
  end
end