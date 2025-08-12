# frozen_string_literal: true

class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  helper :all

  helper_method :current_session, :current_user, :user_is_admin?, :current_user_is_superadmin?, :impersonating?

  before_action :set_locale, :set_timezone, :check_account_status, :check_subscription_status, :find_datebooks, :prevent_impersonation_mutations

  before_bugsnag_notify :add_user_info_to_bugsnag

  def check_account_status
    if current_user && (current_user.practice.status == 'cancelled')
      session.clear
      redirect_to signin_url, alert: I18n.t(:account_cancelled)
    end
  end

  def check_subscription_status
    if current_user && !current_user.practice.subscription.active_or_trialing?
      redirect_to_subscription_error
    elsif current_user && current_user.practice.subscription.is_trial_expired?
      redirect_to_subscription_error
    elsif current_user && current_user.practice.subscription.is_trial_expiring?
      flash[:warning] = I18n.t('subscriptions.errors.expiring', practice_settings_url: practice_settings_url).html_safe
    elsif current_user && current_user.practice.subscription.status == 'past_due'
      flash[:warning] = I18n.t('subscriptions.errors.past_due', practice_settings_url: practice_settings_url).html_safe
    end
  end

  def set_locale
    I18n.locale = current_user&.practice&.locale || I18n.default_locale
  end

  def set_timezone
    Time.zone = current_user&.practice&.timezone if current_user
  end

  private

  def redirect_to_subscription_error
    if user_is_admin?
      redirect_to practice_settings_url, flash: { error: I18n.t('subscriptions.errors.expired') }
    else
      session.clear
      redirect_to signin_url, flash: { error: I18n.t('subscriptions.errors.expired_non_admin') }
    end
  end

  def current_user
    return @current_user if defined?(@current_user)

    # First, try to find user from session
    @current_user ||= User.find(session[:user]['id']) if session[:user]
    
    # If no session user, check for remember token in cookies
    if @current_user.nil? && cookies[:remember_token].present?
      user = User.find_by(remember_token: cookies[:remember_token])
      if user&.remember_token_valid?
        # Extend the remember token and set session
        user.remember_me!
        session[:user] = user
        cookies[:remember_token] = { 
          value: user.remember_token, 
          expires: user.remember_token_expires_at,
          secure: Rails.application.config.force_ssl,
          httponly: true,
          same_site: :lax
        }
        @current_user = user
      else
        # Clear invalid remember token
        cookies.delete(:remember_token)
      end
    end
    
    @current_user
  end

  def user_is_admin?(user = current_user)
    return true if user.roles.include?('admin')
  end

  def find_datebooks
    @datebooks = Datebook.with_practice(current_user.practice_id).order('name') if current_user
  end

  def current_user_is_superadmin?
    current_user&.roles&.include?('superadmin')
  end

  def impersonating?
    session[:impersonator_id].present?
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
    unless current_user_is_superadmin?
      redirect_back_or_default('/401', I18n.t(:admin_credentials_required))
      return
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

  def prevent_impersonation_mutations
    return unless session[:impersonator_id].present?
    return if request.get? || request.head?
    
    respond_to do |format|
      format.html { 
        redirect_back_or_default(request.referer || root_path, I18n.t(:impersonation_mutation_blocked, default: 'Data modification is not allowed while impersonating.'))
      }
      format.json { 
        render json: { error: I18n.t(:impersonation_mutation_blocked, default: 'Data modification is not allowed while impersonating.') }, status: :forbidden 
      }
      format.js { 
        render json: { error: I18n.t(:impersonation_mutation_blocked, default: 'Data modification is not allowed while impersonating.') }, status: :forbidden 
      }
    end
  end

  def authenticate_and_set_session(user, password, remember_me = false)
    if user&.authenticate(password)
      # Update the last time this person was seen online (only for existing users)
      user.update(last_login_at: user.current_login_at, current_login_at: Time.now) if user.persisted?
      
      # Save the user in that user's session cookie:
      session[:user] = user
      
      # Set remember token if remember_me is checked
      if remember_me
        user.remember_me!
        cookies[:remember_token] = { 
          value: user.remember_token, 
          expires: user.remember_token_expires_at,
          secure: Rails.application.config.force_ssl,
          httponly: true,
          same_site: :lax
        }
      end
      
      true
    else
      false
    end
  end
end
