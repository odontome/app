# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

# expire_after is stored inside the encrypted cookie, so the server rejects an
# old cookie even if it's copied out of the browser. It's renewed on every
# request, so it only signs out a browser left idle that long; "remember me"
# (2 weeks) quietly starts a new session after that.
Rails.application.config.session_store :cookie_store,
  key: '_odontome_session',
  expire_after: 12.hours,
  secure: Rails.application.config.force_ssl,
  httponly: true,
  same_site: :lax
