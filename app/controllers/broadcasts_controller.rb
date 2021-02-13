class BroadcastsController < ApplicationController
  before_action :require_user

  def index
    @broadcasts = Broadcast.with_practice(current_user.practice_id)
  end

  def show
    @broadcast = Broadcast.with_practice(current_user.practice_id).find(params[:id])
  end

  def new
    @broadcast = Broadcast.new
  end

  def create
    @broadcast = Broadcast.new(params[:broadcast])

    respond_to do |format|
      if @broadcast.save
        format.html { redirect_to(broadcasts_url, notice: t(:broadcast_created_success_message)) }
      else
        format.html { render action: 'new' }
      end
    end
  end

  def destroy
    @broadcast = Broadcast.with_practice(current_user.practice_id).find(params[:id])
    @broadcast.destroy

    respond_to do |format|
      format.html { redirect_to(broadcasts_url) }
    end
  end
end
