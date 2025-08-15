# frozen_string_literal: true

class ConnectAccountsController < ApplicationController
  before_action :require_user
  before_action :require_practice_admin

  def show
    @practice = current_user.practice

    return unless @practice.has_connect_account?

    @practice.refresh_connect_account_status!
  end

  def create
    @practice = current_user.practice

    begin
      @practice.create_connect_account!
      redirect_to onboarding_connect_account_path
    rescue Stripe::StripeError => e
      flash[:error] = I18n.t('stripe_account.account_created_error_message')
      Rails.logger.error "Error while creating Connect account for practice #{@practice.id}: #{e.message}"
      redirect_to practice_settings_path
    end
  end

  def onboarding
    @practice = current_user.practice

    unless @practice.has_connect_account?
      flash[:error] = I18n.t('stripe_account.account_onboarding_error_message')
      redirect_to practice_settings_path
      return
    end

    begin
      return_url = connect_account_url
      refresh_url = onboarding_connect_account_url

      account_link = @practice.create_connect_onboarding_link(return_url, refresh_url)
      redirect_to account_link.url, allow_other_host: true
    rescue Stripe::StripeError => e
      flash[:error] = I18n.t('stripe_account.account_created_error_message')
      Rails.logger.error "Error while creating Connect account link for practice #{@practice.id}: #{e.message}"
      redirect_to practice_settings_path
    end
  end

  def refresh_status
    @practice = current_user.practice

    if @practice.has_connect_account?
      begin
        @practice.refresh_connect_account_status!
        flash[:notice] = I18n.t('stripe_account.account_refresh_success_message')
      rescue Stripe::StripeError => e
        flash[:error] = I18n.t('stripe_account.account_refresh_error_message')
        Rails.logger.error "Error while refreshing Connect account status for practice #{@practice.id}: #{e.message}"
      end
    end

    redirect_to connect_account_path
  end
end
