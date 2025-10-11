# frozen_string_literal: true

require_relative 'boot'

require 'csv'
require 'rails/all'
require 'sprockets/railtie'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Odontome
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

    # Do not swallow errors in after_commit/after_rollback callbacks.
    # config.active_record.raise_in_transactional_callbacks = true

    config.enable_dependency_loading = true
    config.autoload_paths << "#{Rails.root}/lib"
    config.load_defaults 8.0
    config.active_support.to_time_preserves_timezone = :zone
    config.active_record.use_schema_cache_dump = true

    ### Odonto.me stuff

    config.i18n.available_locales = %w[es en pt]
    config.i18n.enforce_available_locales = false

    # load the predefined list of treatments
    config.patient_treatments = YAML.safe_load(File.open("#{Rails.root}/config/treatments.yml"))

    # disabled field error behavior
    config.action_view.field_error_proc = proc do |html_tag, _instance|
      html_tag
    end

    # Protect from mass assignments
    # config.active_record.whitelist_attributes = true

    # Configure the default encoding used in templates for Ruby 1.9.
    # config.encoding = "utf-8"

    # To configure the SSL Enforcer gem
    # config.middleware.use Rack::SslEnforcer, :only => ["/signup", "/signin", "/users/new", /^\/users\/(.+)\/edit/, "/set_session_time_zone"], :mixed => true, , :except_hosts => '0.0.0.0'

    # enable custom error pages
    config.exceptions_app = routes
    config.action_controller.permit_all_parameters = true
  end
end
