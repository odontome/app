# frozen_string_literal: true

class WelcomeController < ApplicationController
  layout 'simple'

  def index
    flash.keep
    if current_user
      redirect_to determine_home_url
    else
      redirect_to :signin
    end
  end

  def privacy; end

  def terms; end

  private

  def determine_home_url
    return practices_admin_url if current_user_is_superadmin?

    # Always attempt to send the user back to their most relevant datebook
    home_datebook = last_visited_datebook || first_available_datebook

    return home_datebook if home_datebook

    # Fall back to pages the user is authorised to see when no datebooks exist yet
    return new_datebook_url if user_is_admin?

    patients_url
  end

  def last_visited_datebook
    return unless session[:LAST_VISITED_DATEBOOK]

    Datebook.with_practice(current_user.practice_id).find_by(id: session[:LAST_VISITED_DATEBOOK])
  end

  def first_available_datebook
    Datebook.with_practice(current_user.practice_id).first
  end
end
