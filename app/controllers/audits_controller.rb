# frozen_string_literal: true

class AuditsController < ApplicationController
  before_action :require_user
  before_action :require_practice_admin

  def index
    @filter_params = {
      user_id: params[:user_id],
    }

    # Start with practice-scoped versions using the metadata
    @versions = PaperTrail::Version.where(practice_id: current_user.practice_id)

    # Apply filters
    @versions = @versions.where(whodunnit: @filter_params[:user_id]) if @filter_params[:user_id].present?

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

    @practice_users = User.with_practice(current_user.practice_id).order('firstname')
  end

  def show
    @version = PaperTrail::Version.where(practice_id: current_user.practice_id).find(params[:id])
    @item = @version.item
    @whodunnit_user = @version.whodunnit.present? ? User.find_by(id: @version.whodunnit) : nil
  end
end
