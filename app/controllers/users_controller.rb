class UsersController < ApplicationController
  before_filter :require_user
  
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
        format.html { redirect_to(users_url, :notice => 'User was successfully created.') }
      else
        format.html { render :action => "new" }
      end
    end
  end

  def update
    @user = User.mine.find(params[:id])

    respond_to do |format|
      if @user.update_attributes(params[:user])
        format.html { redirect_to(@user, :notice => 'User was successfully updated.') }
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
