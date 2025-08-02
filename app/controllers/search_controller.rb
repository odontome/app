# frozen_string_literal: true

class SearchController < ApplicationController
  before_action :require_user

  def index
    @search_term = params[:term]
    @results = { patients: [], doctors: [], treatments: [] }

    if @search_term.present?
      @results[:patients] = Patient.search(@search_term).with_practice(current_user.practice_id)
      @results[:doctors] = Doctor.search(@search_term).with_practice(current_user.practice_id)
      @results[:treatments] = Treatment.search(@search_term).with_practice(current_user.practice_id)
    end

    respond_to do |format|
      format.html
      format.json { render json: @results }
    end
  end
end