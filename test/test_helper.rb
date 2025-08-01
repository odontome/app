# frozen_string_literal: true

# Load coverage tracking if enabled
require_relative 'coverage_helper' if ENV['COVERAGE']

ENV['RAILS_ENV'] ||= 'test'
require File.expand_path('../config/environment', __dir__)
require 'rails/test_help'

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