[![Deploy](https://www.herokucdn.com/deploy/button.svg)](https://heroku.com/deploy?template=https://github.com/odontome/app)

☝️ For one-click deployment

## Local development

- Install [Homebrew](https://brew.sh)
- Install the [Heroku CLI](https://devcenter.heroku.com/articles/heroku-cli)
- Run `bundle install`

## Database initialization

Run the following command from the terminal `bundle exec rake db:setup` followed by `bundle exec rake db:migrate`.

## How to run the test suite

Run the following command from the terminal `bundle exec rake test`.

## Deployment instructions

Heroku deploys automatically every commit on the `master` branch to the staging environment. Is important to keep the branch in a deployable state.

## Required environment variables

Include the following environment variables in your local and remote instance for the application to work correctly.

| Key                      | Description                                       | Required |
| ------------------------ | ------------------------------------------------- | -------- |
| `SECRET_KEY_BASE`        | Rails secret key, used to secure your application | Yes      |
| `STRIPE_PUBLISHABLE_KEY` | Used by Stripe for subscription management        | Yes      |
| `STRIPE_SECRET_KEY`      | See above                                         | Yes      |
| `STRIPE_WEBHOOK_SECRET`  | Used by Stripe to authenticate your requests      | Yes      |
| `STRIPE_PRICE_ID`        | Used by Stripe for the subscription price         | Yes      |
| `SENDGRID_API_KEY`       | Used by Sendgrid in order to use Rails Mailers    | Yes      |
| `SENDGRID_DOMAIN`        | See above                                         | Yes      |
| `SENDGRID_USERNAME`      | See above                                         | Yes      |
| `SENDGRID_PASSWORD`      | See above                                         | Yes      |
| `BUGSNAG_API_KEY`        | Used by Bugsnag for error tracking                | No       |

## Setting up Scheduler

Add all the jobs in `/lib/tasks/odontome.rake` to your Scheduler Heroky extension.

## Setting up Stripe

Watch all the events in `/app/controllers/api/webhooks/stripe_controller.rb` in the developer section of your Stripe dashboard.
