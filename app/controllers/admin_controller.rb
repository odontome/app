# frozen_string_literal: true

class AdminController < ApplicationController
  before_action :require_superadmin

  def practices
    @total_practices = Practice.count
    @practices = Practice.includes(:subscription).order('created_at desc').limit(250)
  end
end
