class AdminController < ApplicationController
  before_action :require_superadmin

  def practices
    @practices = Practice.select('id, name, created_at, cancelled_at, datebooks_count, patients_count, doctors_count, users_count').order('created_at desc')
  end
end
