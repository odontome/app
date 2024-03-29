# frozen_string_literal: true

class UserSessionsController < ApplicationController
  before_action :require_user, only: %i[show destroy]
  skip_before_action :check_subscription_status

  def new; end

  def show; end

  def create
    # Look up User in db by the email address submitted to the login form and
    # convert to lowercase to match email in db in case they had caps lock on:
    user = User.find_by(email: params[:signin][:email].downcase)

    # While users migrate to the new version, force them to reset their passwords
    if !user.nil? && !user.password_digest.present?
      flash[:alert] = I18n.t('errors.messages.reset_your_password_request')
      redirect_to new_password_reset_url
    # Verify user exists in db and run has_secure_password's .authenticate()
    # method to see if the password submitted on the login form was correct:
    elsif user&.authenticate(params[:signin][:password])
      # Update the last time this person was seen online
      user.update(last_login_at: user.current_login_at, current_login_at: Time.now)

      # Save the user in that user's session cookie:
      session[:user] = user
      redirect_to root_url
    else
      # if email or password incorrect, re-render login page:
      flash[:alert] = I18n.t('errors.titles.not_found')
      render action: :new
    end
  end

  def destroy
    session.clear
    redirect_to root_url
  end
end
