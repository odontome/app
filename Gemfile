# frozen_string_literal: true

source 'https://rubygems.org'
ruby '2.7.2'

### default rails stuff

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'bcrypt', '~> 3.1.7'
gem 'jquery-rails', '~> 4.4.0'
gem 'puma', '~> 4.3.5'
gem 'rails', '~> 5.2.0'
gem 'sass-rails', '~> 5.0'
gem 'uglifier', '~> 4.2.0'

### rails backward compatibility

gem 'protected_attributes_continued', '~> 1.5.0'

### odonto.me specifc

gem 'icalendar', '~> 2.6.1'
gem 'mandrill-api', '~> 1.0.53'
gem 'rails-i18n', '~> 5.1.3'
gem 'taps', '~> 0.3.24'

gem 'font-awesome-rails', '~> 4.7.0.5'
gem 'gibberish', '~> 2.1.0'
gem 'jquery-minicolors-rails', '~>2.2.6.2'

gem 'premailer-rails', '~> 1.11.1'
gem 'rails_select_on_includes', '~> 5.2.1'

gem 'airbrake'
gem 'pg', '~> 1.2.3'

group :development do
  gem 'brakeman', '~> 4.9.0'
  gem 'i18n-tasks', '~> 0.9.23'
  gem 'listen', '~> 3.2.1'
  gem 'web-console', '~> 3.7.0'
  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem 'rubocop'
  gem 'spring-watcher-listen', '~> 2.0.1'
end

group :production do
end

group :test do
  # pretty printed test output
  # gem 'turn'
end

group :development, :test do
  gem 'byebug', '~> 11.1.3'
  gem 'rails-controller-testing', '~> 1.0.5'
  gem 'spring', '~> 2.1.0'
end
