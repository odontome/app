require 'stripe'

# Try to load secrets from the config, fallback to ENV variables
stripe_config = begin
  # Load from secrets.yml
  secrets = Rails.application.config_for(:secrets)
  {
    publishable_key: secrets['stripe_publishable_key'],
    secret_key: secrets['stripe_secret_key'],
    webhook_secret: secrets['stripe_webhook_secret'],
    price_id: secrets['stripe_price_id']
  }
rescue
  # Fallback to environment variables
  {
    publishable_key: ENV['STRIPE_PUBLISHABLE_KEY'],
    secret_key: ENV['STRIPE_SECRET_KEY'],
    webhook_secret: ENV['STRIPE_WEBHOOK_SECRET'],
    price_id: ENV['STRIPE_PRICE_ID']
  }
end

Rails.configuration.stripe = {
  :publishable_key => stripe_config[:publishable_key],
  :secret_key => stripe_config[:secret_key],
  :webhook_secret => stripe_config[:webhook_secret],
  :price_id => stripe_config[:price_id]
}

Stripe.api_key = Rails.configuration.stripe[:secret_key]
Stripe.api_version = '2018-11-08'