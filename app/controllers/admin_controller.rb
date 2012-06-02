class AdminController < ApplicationController

  before_filter :require_superadmin
  respond_to :html

  def practices
    @practices = Practice.select("id, name, created_at, patients_count, appointments_count, doctors_count, users_count")

  end
  
end
