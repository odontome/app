# frozen_string_literal: true

class AuditsController < ApplicationController
  before_action :require_user
  before_action :require_practice_admin

  def index
    @filter_params = {
      item_type: params[:item_type],
      event: params[:event],
      user_id: params[:user_id],
      date_from: params[:date_from],
      date_to: params[:date_to]
    }

    # Start with practice-scoped versions using the metadata
    @versions = PaperTrail::Version.where(practice_id: current_user.practice_id)

    # Apply filters
    @versions = @versions.where(item_type: @filter_params[:item_type]) if @filter_params[:item_type].present?
    @versions = @versions.where(event: @filter_params[:event]) if @filter_params[:event].present?
    @versions = @versions.where(whodunnit: @filter_params[:user_id]) if @filter_params[:user_id].present?

    if @filter_params[:date_from].present?
      begin
        date_from = Date.parse(@filter_params[:date_from]).beginning_of_day
        @versions = @versions.where('versions.created_at >= ?', date_from)
      rescue ArgumentError
        # Invalid date format, ignore filter
      end
    end

    if @filter_params[:date_to].present?
      begin
        date_to = Date.parse(@filter_params[:date_to]).end_of_day
        @versions = @versions.where('versions.created_at <= ?', date_to)
      rescue ArgumentError
        # Invalid date format, ignore filter
      end
    end

    # Pagination setup
    @page = params[:page].to_i
    @page = 0 if @page < 0
    @per_page = 25
    
    # Get total count for pagination info
    @total_count = @versions.count
    @total_pages = (@total_count.to_f / @per_page).ceil
    @has_next_page = @page < (@total_pages - 1)
    @has_prev_page = @page > 0
    
    # Apply pagination and ordering
    @versions = @versions.order(created_at: :desc)
                        .limit(@per_page)
                        .offset(@page * @per_page)

    # Get available filter options
    @available_types = ['Patient', 'Doctor', 'User', 'Appointment', 'Practice', 'Treatment', 'Datebook']
    @available_events = ['create', 'update', 'destroy']
    @practice_users = User.with_practice(current_user.practice_id).order('firstname')
  end

  def show
    @version = PaperTrail::Version.where(practice_id: current_user.practice_id).find(params[:id])
    @item = @version.item
  end

  private

  # No longer needed since we filter by practice_id in the query
  # def version_belongs_to_practice?(version)
  #   ...
  # end
end
