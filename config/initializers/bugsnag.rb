Bugsnag.configure do |config|
  config.api_key = ENV['BUGSNAG_API_KEY']

  # Bots probing with malformed Accept headers raise this before any app code
  # runs; Rails already answers 406, so reporting it is pure noise.
  config.discard_classes << 'ActionDispatch::Http::MimeNegotiation::InvalidType'
end
