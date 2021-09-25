# frozen_string_literal: true

class AdminController < ApplicationController
  before_action :require_superadmin

  def practices
    @practices = Practice.select('
      practices.id,
      practices.name,
      practices.email,
      practices.created_at,
      practices.cancelled_at,
      practices.datebooks_count,
      practices.patients_count,
      practices.doctors_count,
      practices.users_count,
      subscriptions.status,
      subscriptions.current_period_end').left_outer_joins(:subscription).order('created_at desc')
  end
end
