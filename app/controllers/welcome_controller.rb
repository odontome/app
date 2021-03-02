# frozen_string_literal: true

class WelcomeController < ApplicationController
  layout 'simple'

  def index
    flash.keep
    if current_user
      if current_user_is_superadmin?
        home_url = practices_admin_url
      elsif session[:LAST_VISITED_DATEBOOK]
        begin
          home_url = Datebook.with_practice(current_user.practice_id).find(session[:LAST_VISITED_DATEBOOK])
        rescue ActiveRecord::RecordNotFound
          home_url = Datebook.with_practice(current_user.practice_id).first
        end
      else
        home_url = Datebook.with_practice(current_user.practice_id).first
      end

      redirect_to home_url
    else
      redirect_to :signin
    end
  end

  def privacy; end

  def terms; end
end
