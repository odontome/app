# frozen_string_literal: true

class AdminController < ApplicationController
  before_action :require_superadmin

  def practices
    @filter = params[:filter] || 'all'
    @total_practices = Practice.count

    if @filter == 'all'
      @practices = Practice.includes(:subscription).order('created_at desc').limit(250)
    elsif @filter == 'active'
      @practices = Practice.includes(:subscription).where(subscriptions: { status: 'active' }).order('practices.created_at desc').limit(250)
    end
  end
end
