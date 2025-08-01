# frozen_string_literal: true

class AdminController < ApplicationController
  before_action :require_superadmin

  def practices
    @filter = params[:filter] || 'all'
    @total_practices = Practice.count

    case @filter
    when 'all'
      @practices = Practice.includes(:subscription).order('created_at desc').limit(250)
    when 'active'
      @practices = Practice.includes(:subscription).where(subscriptions: { status: 'active' }).order('practices.created_at desc').limit(250)
    when 'trialing'
      @practices = Practice.includes(:subscription).where(subscriptions: { status: 'trialing' }).order('practices.created_at desc').limit(250)
    when 'past_due'
      @practices = Practice.includes(:subscription).where(subscriptions: { status: 'past_due' }).order('practices.created_at desc').limit(250)
    when 'canceled'
      @practices = Practice.includes(:subscription).where(subscriptions: { status: 'canceled' }).order('practices.created_at desc').limit(250)
    else
      @practices = Practice.includes(:subscription).order('created_at desc').limit(250)
    end
  end
end
