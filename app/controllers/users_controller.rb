class UsersController < ApplicationController
  before_action :require_user
  before_action :require_practice_admin, :except => [:show, :edit, :update]

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
    @user = User.new(params[:user])
    @user.practice_id = current_user.practice_id

    respond_to do |format|
      if @user.save
        format.html { redirect_to(users_url, :notice => I18n.t(:user_created_success_message)) }
      else
        format.html { render :action => "new" }
      end
    end
  end

  def update
    @user = User.with_practice(current_user.practice_id).find(params[:id])

    respond_to do |format|
      # prevent normal users from changing admins
      if @user.roles.include?("admin") && !current_user.roles.include?("admin")
        format.html { render :action => "edit", :error => I18n.t("errors.messages.unauthorised")}
      end

      if @user.update_attributes(params[:user])
        format.html { redirect_to(@user, :notice => I18n.t(:user_updated_success_message)) }
      else
        format.html { render :action => "edit" }
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

  def unsubscribe
    @user = User.with_practice(current_user.practice_id).find(params[:id])

    if params.key?(:undo)
      @user.subscribed_to_digest = true
    else
      @user.subscribed_to_digest = false
    end

    @user.save

    redirect_to @user
  end

end
