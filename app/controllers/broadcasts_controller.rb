class BroadcastsController < ApplicationController
  before_filter :require_user

  def index
    @broadcasts = Broadcast.mine
  end

  def show
    @broadcast = Broadcast.mine.find(params[:id])
  end

  def new
    @broadcast = Broadcast.new
  end

  def create
    @broadcast = Broadcast.new(params[:broadcast])

    respond_to do |format|
      if @broadcast.save
        format.html { redirect_to(broadcasts_url, :notice => t(:broadcast_created_success_message))}
      else
        format.html { render :action => "new" }
      end
    end
  end

  def destroy
    @broadcast = Broadcast.mine.find(params[:id])
    @broadcast.destroy

    respond_to do |format|
      format.html { redirect_to(broadcasts_url) }
    end
  end

end