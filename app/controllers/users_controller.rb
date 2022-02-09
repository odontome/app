# frozen_string_literal: true

class UsersController < ApplicationController
  before_action :require_user
  before_action :require_practice_admin, except: %i[show edit update]

  def index
    @users = User.with_practice(current_user.practice_id)
  end

  def show
    @user = User.with_practice(current_user.practice_id).find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
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
      # prevent normal users from changing admins
      if @user.roles.include?('admin') && !current_user.roles.include?('admin')
        format.html { render action: 'edit', error: I18n.t('errors.messages.unauthorised') }
      end

      if @user.update(user_params)
        format.html { redirect_to(@user, notice: I18n.t(:user_updated_success_message)) }
      else
        format.html { render action: 'edit' }
      end
    end
  end

  def destroy
    @user = User.with_practice(current_user.practice_id).find(params[:id])
    @user.destroy

    respond_to do |format|
      format.html { redirect_to(users_url) }
    end
  end

  private

  def user_params
    params.require(:user).permit(:firstname, :lastname, :email, :password, :password_confirmation)
  end
end
