ENV['RAILS_ENV'] ||= 'test'
require File.expand_path('../../config/environment', __FILE__)
require 'rails/test_help'
require "authlogic/test_case"

class ActiveSupport::TestCase
  fixtures :all
  setup :activate_authlogic
end

class ActionController::TestCase
  setup :activate_authlogic
end