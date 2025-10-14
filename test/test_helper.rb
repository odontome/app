# frozen_string_literal: true

ENV['RAILS_ENV'] ||= 'test'
require File.expand_path('../config/environment', __dir__)
require 'rails/test_help'

Dir[Rails.root.join('test/support/**/*.rb')].sort.each { |f| require f }

module ActiveSupport
  class TestCase
    fixtures :all

    ActiveModel::SecurePassword.min_cost = true
  end
end

module ActionController
  class TestCase
  end
end