class AuditsController < ApplicationController

  before_filter :require_practice_admin  
  
  def index
    @audits = Audit.recent
  end

  def show
    
  end

end
