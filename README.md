[![Deploy](https://www.herokucdn.com/deploy/button.svg)](https://heroku.com/deploy?template=https://github.com/odontome/app)

## Local development

- Install [Homebrew](https://brew.sh)
- Install the [Heroku CLI](https://devcenter.heroku.com/articles/heroku-cli)
- Run `bundle install`

## Database initialization

Run the following command from the terminal `bundle exec rake db:setup` followed by `bundle exec rake db:migrate`.

## How to run the test suite

Run the following command from the terminal `bundle exec rake test`.

## Deployment instructions

Heroku deploys automatically every commit on the `master` branch. So, is very important to keep that branch in a deployable state.

## Required environment variables

Include the following environment variables in your local and remote instance for the application to work correctly.

| Key                    | Description                                       | Required |
| ---------------------- | ------------------------------------------------- | -------- |
| SECRET_KEY_BASE        | Rails secret key, used to secure your application | Yes      |
| STRIPE_PUBLISHABLE_KEY | Used by Stripe for subscription management        | Yes      |
| STRIPE_SECRET_KEY      | See `STRIPE_PUBLISHABLE_KEY`                      | Yes      |
| STRIPE_WEBHOOK_SECRET  | Used by Stripe to authenticate your requests      | Yes      |
| STRIPE_PRICE_ID        | Used by Stripe for the subscription price         | Yes      |
| BUGSNAG_API_KEY        | Used by Bugsnag for error tracking                | No       |
| SENDGRID_API_KEY       | Used by Sendgrid in order to use Rails Mailers    | No       |
| SENDGRID_DOMAIN        | See `SENDGRID_API_KEY`                            | No       |
| SENDGRID_USERNAME      | See `SENDGRID_API_KEY`                            | No       |
| SENDGRID_PASSWORD      | See `SENDGRID_API_KEY`                            | No       |
