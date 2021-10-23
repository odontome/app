# frozen_string_literal: true

class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  helper :all

  helper_method :current_session, :current_user, :user_is_admin?

  before_action :set_locale, :set_timezone, :check_account_status, :check_subscription_status, :find_datebooks

  before_bugsnag_notify :add_user_info_to_bugsnag

  def check_account_status
    if current_user && (current_user.practice.status == 'cancelled')
      session.clear
      redirect_to signin_url, alert: I18n.t(:account_cancelled)
    end
  end

  def check_subscription_status
    if current_user && current_user.practice.subscription.is_trial_expiring?
      flash[:warning] = I18n.t('subscriptions.errors.expiring', practice_settings_url: practice_settings_url).html_safe
    elsif current_user && !current_user.practice.subscription.active_or_trialing?
      if user_is_admin?
        redirect_to practice_settings_url, flash: { error: I18n.t('subscriptions.errors.expired') }
      else
        session.clear
        redirect_to signin_url, flash: { error: I18n.t('subscriptions.errors.expired_non_admin') }
      end
    end
  end

  def set_locale
    I18n.locale = session[:locale] || I18n.default_locale
  end

  def set_timezone
    Time.zone = current_user.practice.timezone if current_user
  end

  private

  def current_user
    return @current_user if defined?(@current_user)

    @current_user ||= User.find(session[:user]['id']) if session[:user]
  end

  def user_is_admin?(user = current_user)
    return true if user.roles.include?('admin')
  end

  def find_datebooks
    @datebooks = Datebook.with_practice(current_user.practice_id).order('name') if current_user
  end

  def current_user_is_superadmin?
    return true if current_user&.roles&.include?('superadmin')
  end

  def require_user
    unless current_user
      store_location
      flash[:notice] = t :not_logged_in
      redirect_to signin_path
      false
    end
  end

  def require_no_user
    if current_user
      store_location
      flash[:notice] = t :not_logged_in
      redirect_to root_path
      false
    end
  end

  def store_location
    session[:return_to] = request.url
  end

  def redirect_back_or_default(default, message = nil)
    return_to = session[:return_to] || default
    redirect_to(return_to, alert: message)
    session[:return_to] = nil
  end

  def require_superadmin
    if current_user
      redirect_back_or_default('/') unless current_user_is_superadmin?
      false
    else
      redirect_back_or_default('/')
      false
    end
  end

  def require_practice_admin
    if current_user
      unless user_is_admin?(current_user)
        redirect_back_or_default('/401', I18n.t(:admin_credentials_required))
        false
      end
    else
      false
    end
  end

  def render_ujs_error(object, message)
    render template: 'shared/ujs/form_errors',
           formats: [:js],
           locals: {
             item: object,
             notice: message
           }
  end

  def add_user_info_to_bugsnag(event)
    event.set_user(current_user.id, current_user.email, current_user.fullname) if current_user
  end
end
