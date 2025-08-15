# frozen_string_literal: true

class ConnectAccountsController < ApplicationController
  before_action :require_user
  before_action :require_practice_admin

  def show
    @practice = current_user.practice
    
    if @practice.has_connect_account?
      @practice.refresh_connect_account_status!
    end
  end

  def create
    @practice = current_user.practice
    
    begin
      @practice.create_connect_account!
      redirect_to connect_onboarding_path
    rescue Stripe::StripeError => e
      flash[:error] = "Failed to create Connect account: #{e.message}"
      redirect_to practice_settings_path
    end
  end

  def onboarding
    @practice = current_user.practice
    
    unless @practice.has_connect_account?
      flash[:error] = "No Connect account found. Please create one first."
      redirect_to practice_settings_path
      return
    end

    begin
      return_url = connect_account_url
      refresh_url = connect_onboarding_url
      
      account_link = @practice.create_connect_onboarding_link(return_url, refresh_url)
      redirect_to account_link.url, allow_other_host: true
    rescue Stripe::StripeError => e
      flash[:error] = "Failed to create onboarding link: #{e.message}"
      redirect_to practice_settings_path
    end
  end

  def refresh_status
    @practice = current_user.practice
    
    if @practice.has_connect_account?
      begin
        @practice.refresh_connect_account_status!
        flash[:notice] = "Account status refreshed successfully"
      rescue Stripe::StripeError => e
        flash[:error] = "Failed to refresh account status: #{e.message}"
      end
    end
    
    redirect_to connect_account_path
  end
end