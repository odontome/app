ENV['RAILS_ENV'] ||= 'test'
require File.expand_path('../config/environment', __dir__)
require 'rails/test_help'

class ActiveSupport::TestCase
  fixtures :all

  ActiveModel::SecurePassword.min_cost = true
end

class ActionController::TestCase
end
