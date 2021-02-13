class PasswordResetsController < ApplicationController
  before_action :require_no_user
  before_action :load_user_using_perishable_token, :only => [ :edit, :update ]

  layout "user_sessions"

  def new
  end

  def create
    @user = User.find_by_email(params[:email])
    if @user
      @user.deliver_password_reset_instructions!
      flash[:notice] = I18n.t(:password_reset_instructions_sent_to_email)
      redirect_to root_path
    else
      flash.now[:error] = I18n.t(:no_user_with_that_email, email: params[:email])
      render :action => :new
    end
  end

  def edit
  end

  def update
    @user.password = params[:password]
    @user.password_confirmation = params[:password]
    if @user.save
      flash[:notice] = I18n.t(:password_reset_success_message)
      redirect_to root_path
    else
      render :action => :edit
    end
  end


  private

  def load_user_using_perishable_token
    @user = User.find_by(perishable_token: params[:id], updated_at: 10.minutes.ago..Time.now)
    unless @user
      flash[:error] = I18n.t(:account_not_found)
      redirect_to root_url
    end
  end
end
