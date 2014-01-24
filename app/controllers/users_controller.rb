class UsersController < ApplicationController
  before_filter :require_user
  before_filter :require_practice_admin, :only => [:index, :destroy]

  def index
    @users = User.mine
  end

  def show
    @user = User.mine.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
    end
  end

  def new
    @user = User.new
  end

  def edit
    @user = User.mine.find(params[:id])
  end

  def create
    @user = User.new(params[:user])

    respond_to do |format|
      if @user.save
        format.html { redirect_to(users_url, :notice => I18n.t(:user_created_success_message)) }
      else
        format.html { render :action => "new" }
      end
    end
  end

  def update
    @user = User.mine.find(params[:id])

    respond_to do |format|
      if @user.update_attributes(params[:user])
        format.html { redirect_to(users_url, :notice => I18n.t(:user_updated_success_message)) }
      else
        format.html { render :action => "edit" }
      end
    end
  end

  def destroy
    @user = User.mine.find(params[:id])
    @user.destroy

    respond_to do |format|
      format.html { redirect_to(users_url) }
    end
  end

end
