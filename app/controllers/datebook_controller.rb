class DatebookController < ApplicationController
  before_filter :require_user
  
  def show
    @doctors = Doctor.mine.order("firstname")
  end

end
