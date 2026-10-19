# frozen_string_literal: true

class UsersController < ApplicationController
  before_action :require_user
  before_action :require_practice_admin, except: %i[show edit update]
  before_action :require_self_or_practice_admin, only: %i[show edit update]

  def index
    @users = User.with_practice(current_user.practice_id)
  end

  def show
    @user = User.with_practice(current_user.practice_id).find(params[:id])

    respond_to do |format|
      format.html
    end
  end

  def new
    @user = User.new
  end

  def edit
    @user = User.with_practice(current_user.practice_id).find(params[:id])
  end

  def create
    @user = User.new(user_params)
    @user.practice_id = current_user.practice_id

    respond_to do |format|
      if @user.save
        format.html { redirect_to(users_url, notice: I18n.t(:user_created_success_message)) }
      else
        format.html { render action: 'new' }
      end
    end
  end

  def update
    @user = User.with_practice(current_user.practice_id).find(params[:id])

    respond_to do |format|
      if @user.update(user_params)
        # A new password signs out other browsers; keep this one signed in
        store_user_in_session(@user) if @user.id == current_user.id && @user.saved_change_to_session_token?
        format.html { redirect_to(@user, notice: I18n.t(:user_updated_success_message)) }
      else
        format.html { render action: 'edit' }
      end
    end
  end

  def destroy
    @user = User.with_practice(current_user.practice_id).find(params[:id])

    respond_to do |format|
      if @user.destroy
        format.html { redirect_to(users_url) }
      else
        format.html { redirect_to(users_url, alert: I18n.t(:user_deleted_admin_error_message)) }
      end
    end
  end

  private

  # admins can manage everyone in their practice, everybody else only themselves
  def require_self_or_practice_admin
    return if user_is_admin?(current_user) || params[:id].to_i == current_user.id

    redirect_back_or_default('/401', I18n.t('errors.messages.unauthorised'))
  end

  def user_params
    params.require(:user).permit(:firstname, :lastname, :email, :password, :password_confirmation)
  end
end
