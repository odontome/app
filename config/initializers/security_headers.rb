# frozen_string_literal: true

# Security headers configuration
Rails.application.config.force_ssl = true if Rails.env.production?

Rails.application.configure do
  config.ssl_options = {
    redirect: {
      exclude: ->(request) { request.path.match?(/health/) }
    }
  }
end

# Add security headers middleware
Rails.application.config.middleware.use Rack::Deflater

if Rails.env.production?
  # Additional security headers for production
  Rails.application.config.session_store :cookie_store,
    key: '_odontome_session',
    secure: true,
    httponly: true,
    same_site: :lax
end