Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # In the development environment your application's code is reloaded on
  # every request. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.cache_classes = false

  # Do not eager load code on boot.
  config.eager_load = false

  # Show full error reports and disable caching.
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false

  # Don't care if the mailer can't send.
  config.action_mailer.raise_delivery_errors = false

  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log

  # Raise an error on page load if there are pending migrations.
  config.active_record.migration_error = :page_load

  # Debug mode disables concatenation and preprocessing of assets.
  # This option may cause significant delays in view rendering with a large
  # number of complex assets.
  config.assets.debug = false

  # Asset digests allow you to set far-future HTTP expiration dates on all assets,
  # yet still be able to expire them through the digest params.
  config.assets.digest = true

  # Adds additional error checking when serving assets at runtime.
  # Checks for improperly declared sprockets dependencies.
  # Raises helpful error messages.
  config.assets.raise_runtime_errors = true

  # Raises error for missing translations
  config.action_view.raise_on_missing_translations = true

  #### Odonto.me stuff

  ENV["REDISTOGO_URL"] = 'redis://redistogo:681bdba6cde45dca00275208cac1a7a0@pearlfish.redistogo.com:9008/'

  # Configure the host for emails
  config.action_mailer.asset_host = "http://0.0.0.0:3000"
  config.action_mailer.default_url_options = { :host => '0.0.0.0:3000' }

  # Do not compress assets
  # config.assets.compile = false
  # config.assets.compress = false
  # config.assets.paths << Rails.root.join('app', 'assets', 'font')
  # config.assets.precompile += %w(.svg .eot .woff .ttf)

  config.log_tags = [:uuid, :remote_ip]

  # Raise exception on mass assignment protection for Active Record models
  config.active_record.mass_assignment_sanitizer = :strict
end
