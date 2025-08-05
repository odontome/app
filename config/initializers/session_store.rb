# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

Rails.application.config.session_store :cookie_store, 
  key: '_odontome_session',
  secure: Rails.application.config.force_ssl,
  httponly: true,
  same_site: :lax
