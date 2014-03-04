class AdminController < ApplicationController

  before_filter :require_superadmin
  respond_to :html

  def practices
    @practices = Practice.select("id, name, created_at, datebooks_count, patients_count, doctors_count, users_count")
  end
  
end
