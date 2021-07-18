##Local development

- Install [Homebrew](https://brew.sh)
- Install the [Heroku CLI](https://devcenter.heroku.com/articles/heroku-cli)
- Run `bundle install`

##Database initialization
Run the following command from the terminal `bundle exec rake db:setup` followed by `bundle exec rake db:migrate`.

##How to run the test suite
Run the following command from the terminal `docker-compose run web rake test`.

##Deployment instructions
Heroku deploys automatically every commit on the `master` branch. So, is very important to keep that branch in a deployable state.
