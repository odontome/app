source 'https://rubygems.org'
ruby '2.4.0'

### default rails stuff

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '5.1.4'
gem 'sass-rails', '~> 5.0'
gem 'uglifier', '>= 1.3.0'
gem 'jquery-rails'
# gem 'unicorn'
gem 'puma'
### rails backward compatibility

gem 'protected_attributes_continued'
gem 'responders', '~> 2.0'

### odonto.me specifc

gem 'authlogic', '3.6.0'
gem 'scrypt', '3.0.6'
gem 'taps'
gem 'rails-i18n', '~> 4.0.0'
gem 'redis', '~> 3.0'
gem 'passbook', '~> 0.3.1'
gem 'mandrill-api'
gem 'icalendar'

gem 'font-awesome-rails'
gem 'jquery-minicolors-rails'
gem 'gibberish', '~> 1.4.0'

gem 'premailer-rails'
gem 'rails_select_on_includes', '~> 0.5.6' 


group :development do
  gem 'sqlite3'
	gem 'i18n-tasks', '~> 0.2.18'
  gem 'brakeman', :require => false
  gem 'web-console', '>= 3.3.0'
  gem 'listen', '>= 3.0.5', '< 3.2'
  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem 'spring-watcher-listen', '~> 2.0.0'

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
  gem 'spring'
  gem 'rails-controller-testing'
end
