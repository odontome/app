source 'https://rubygems.org'
ruby '2.0.0'

### default rails stuff

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '4.2.0'
gem 'sass-rails', '~> 5.0'
gem 'uglifier', '>= 1.3.0'
gem 'jquery-rails'
gem 'unicorn'

### rails backward compatibility

gem 'protected_attributes'
gem 'responders', '~> 2.0'

### odonto.me specifc

gem 'authlogic', '3.4.4'
gem 'scrypt', '1.2.1'
gem 'taps'
gem 'will_paginate', '~> 3.0'
gem 'rails-i18n', '~> 4.0.0'
gem 'redis', '3.0.5'
gem 'passbook', '~> 0.3.1'
gem 'mixpanel-ruby'
gem 'mandrill-api'
gem 'icalendar'

gem 'font-awesome-rails'
gem 'jquery-minicolors-rails'
gem 'gibberish', '~> 1.4.0'

gem 'premailer-rails'
gem 'hpricot'

group :development do
  gem 'sqlite3'
	gem 'i18n-tasks', '~> 0.2.18'
  gem 'brakeman', :require => false
end

group :production do
	# gems specifically for Heroku go here
  gem 'rails_12factor'
	gem 'pg'
end

group :test do
	# pretty printed test output
	# gem 'turn'
end

group :development, :test do
  # gem 'byebug'
  gem 'web-console', '~> 2.0'
  gem 'spring'
end
