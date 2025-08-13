# frozen_string_literal: true

class AuditsController < ApplicationController
  before_action :require_user
  before_action :require_practice_admin

  def index
    @versions = PaperTrail::Version
                  .where(practice_id: current_user.practice_id)
                  .includes(:item)
                  .order('created_at DESC')
    
    # Apply filters
    if params[:item_type].present?
      @versions = @versions.where(item_type: params[:item_type])
    end
    
    if params[:event].present?
      @versions = @versions.where(event: params[:event])
    end
    
    if params[:user_id].present?
      @versions = @versions.where(whodunnit: params[:user_id])
    end

    if params[:date_from].present?
      @versions = @versions.where('created_at >= ?', Date.parse(params[:date_from]))
    end

    if params[:date_to].present?
      @versions = @versions.where('created_at <= ?', Date.parse(params[:date_to]).end_of_day)
    end

    # Pagination
    @page = (params[:page] || 1).to_i
    @per_page = 25
    @total_count = @versions.count
    @versions = @versions.limit(@per_page).offset((@page - 1) * @per_page)
    
    @total_pages = (@total_count.to_f / @per_page).ceil
    
    # Data for filters
    @available_item_types = PaperTrail::Version
                              .where(practice_id: current_user.practice_id)
                              .distinct
                              .pluck(:item_type)
                              .compact
                              .sort
    
    @available_users = User.with_practice(current_user.practice_id)
                          .select(:id, :firstname, :lastname)
                          .order(:firstname)
  end

  def show
    @version = PaperTrail::Version
                 .where(practice_id: current_user.practice_id)
                 .find(params[:id])
    
    @changeset = @version.changeset
    @item = @version.item
    @user = User.find_by(id: @version.whodunnit) if @version.whodunnit
  rescue ActiveRecord::RecordNotFound
    redirect_to audits_path, alert: I18n.t('errors.messages.not_found')
  end
end