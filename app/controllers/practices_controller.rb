class PracticesController < ApplicationController
  before_action :require_user, only: %i[index destroy edit settings show close]
  before_action :require_no_user, only: %i[new create]
  before_action :require_superadmin, only: %i[index destroy edit]
  before_action :require_practice_admin, only: %i[settings balance update close]

  def index
    @practices = Practice.all
  end

  def show
    @practice = current_user.practice

    starts_at = DateTime.now.at_beginning_of_day
    ends_at = starts_at + 24.hours
    @today_balance = Balance.find_between(starts_at, ends_at, current_user.practice_id).sum(:amount)
    @reviews_count = Review.with_practice(current_user.practice_id).count
  end

  def new
    @practice = Practice.new
    @practice.users.build
    @user = User.new

    render layout: 'user_sessions'
  end

  def edit
    @practice = current_user.practice
  end

  def create
    @practice = Practice.new(params[:practice])

    respond_to do |format|
      if @practice.save

        # find the previously created user
        new_user = @practice.users.first
        PracticeMailer.welcome_email(@practice).deliver_now
        format.html { redirect_to(practice_path) }
      else
        format.html { render action: 'new', as: :signup, layout: 'user_sessions' }
      end
    end
  end

  def update
    @practice = current_user.practice
    session[:locale] = params[:practice][:locale]

    respond_to do |format|
      if @practice.update_attributes(params[:practice])
        format.html { redirect_to(practice_settings_url, notice: t(:practice_updated_success_message)) }
      else
        format.html { render action: 'settings' }
      end
    end
  end

  def cancel
    # LOL this does nothing
  end

  def close
    if current_user.practice.status == 'active'
      flash[:alert] = I18n.t(:practice_close_active_message)
      redirect_to practice_settings_url
    else
      @practice = current_user.practice
      @practice.set_as_cancelled
      if @practice.save
        session.clear
        flash.discard
        redirect_to signin_url, notice: I18n.t(:practice_close_success_message)
      else
        @practice.errors[:base] << I18n.t(:practice_close_error_message)
        redirect_to practice_settings_url
      end
    end
  end

  def destroy
    @practice = Practice.find(params[:id])
    @practice.destroy

    respond_to do |format|
      format.html { redirect_to(practices_url) }
      format.xml  { head :ok }
    end
  end

  def settings
    @practice = current_user.practice
  end

  def balance
    starts_at = if params[:created_at]
                  DateTime.parse params[:created_at]
                else
                  DateTime.now
                end

    starts_at = starts_at.at_beginning_of_day
    ends_at = starts_at + 24.hours

    @selected_date = starts_at.strftime('%A, %d %B %y')

    @balances = Balance.find_between starts_at, ends_at, @current_user.practice_id
    @total = @balances.sum(:amount)

    respond_to do |format|
      format.html
      format.csv do
        headers['Content-Type'] = 'text/csv'
        headers['Content-disposition'] = "attachment; filename=#{starts_at}.csv"
      end
    end
  end
end
