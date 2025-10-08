# frozen_string_literal: true

class AdminController < ApplicationController
  before_action :require_superadmin
  skip_before_action :require_superadmin, only: %i[stop_impersonating]
  skip_before_action :prevent_impersonation_mutations, only: %i[impersonate stop_impersonating]

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

    @profile_picture_counts = ProfilePictureCounter.counts_for_practices(@practices)
  end

  def impersonate
    # Prevent nested impersonation
    if session[:impersonator_id].present?
      redirect_back_or_default('/401', I18n.t('errors.messages.unauthorised'))
      return
    end

    practice = Practice.find(params[:id])
    target_user = practice.users.order('id ASC').first

    unless target_user
      redirect_back_or_default(practices_admin_path, I18n.t('errors.messages.unauthorised'))
      return
    end

    # Store the superadmin id to allow reverting
    session[:impersonator_id] = current_user.id

    # Switch session to target user (do not copy cookies or remember tokens)
    session[:user] = target_user

    flash.discard
    redirect_to practice_path,
                notice: I18n.t(:impersonation_started, default: 'You are now impersonating this practice.')
  end

  def stop_impersonating
    if session[:impersonator_id]
      admin = User.find_by(id: session[:impersonator_id])
      session.delete(:impersonator_id)
      if admin
        session[:user] = admin
        redirect_to practices_admin_path, notice: I18n.t(:impersonation_stopped, default: 'Stopped impersonation.')
        return
      end
    end

    redirect_to root_path, alert: I18n.t('errors.messages.unauthorised')
  end
end
