# frozen_string_literal: true

if ENV['AGENT_COVERAGE'] == '1'
  require 'simplecov'

  SimpleCov.start do
    root File.expand_path('..', __dir__)
    cover 'app/controllers/api/agent/**/*.rb', 'app/models/agent_oauth_*.rb'
    minimum_coverage 100
  end
end

ENV['RAILS_ENV'] ||= 'test'
require File.expand_path('../config/environment', __dir__)
require 'rails/test_help'
require 'stringio'

Dir[Rails.root.join('test/support/**/*.rb')].sort.each { |f| require f }

module ActiveSupport
  class TestCase
    fixtures :all

    ActiveModel::SecurePassword.min_cost = true

    # Controllers set I18n.locale globally; don't let it leak between tests
    teardown { I18n.locale = I18n.default_locale }
  end
end

module ActionController
  class TestCase
  end
end
