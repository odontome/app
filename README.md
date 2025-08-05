# Odontome App

[![Deploy](https://www.herokucdn.com/deploy/button.svg)](https://heroku.com/deploy?template=https://github.com/odontome/app)

☝️ For one-click deployment

## Prerequisites (macOS)

Before setting up the application locally, ensure you have the following installed:

### 1. Command Line Tools and Homebrew
```bash
# Install Xcode Command Line Tools
xcode-select --install

# Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### 2. Ruby 3.2.3
We recommend using rbenv for Ruby version management:

```bash
# Install rbenv and ruby-build
brew install rbenv ruby-build

# Add rbenv to your shell profile (.zshrc, .bash_profile, etc.)
echo 'if which rbenv > /dev/null; then eval "$(rbenv init -)"; fi' >> ~/.zshrc
source ~/.zshrc

# Install Ruby 3.2.3
rbenv install 3.2.3
rbenv global 3.2.3

# Verify installation
ruby --version  # Should show ruby 3.2.3
```

### 3. Node.js and Yarn
```bash
# Install Node.js (LTS version recommended)
brew install node

# Install Yarn package manager
brew install yarn

# Verify installations
node --version  # Should show v18+ or v20+
yarn --version  # Should show 1.22+
```

### 4. PostgreSQL
```bash
# Install PostgreSQL
brew install postgresql@14

# Start PostgreSQL service
brew services start postgresql@14

# Create a database user (optional, for development)
createuser -s $(whoami)
```

### 5. Additional Tools
```bash
# Install Git (if not already installed)
brew install git
```

## Local Development Setup

Follow these steps to set up the application on your macOS machine:

### Quick Setup (Recommended)
```bash
# Clone the repository
git clone https://github.com/odontome/app.git
cd app

# Install dependencies
bundle install
yarn install

# Set up environment variables
cp .env.example .env
# Edit .env with your values (see Environment Variables section below)

# Set up the database
bundle exec rails db:setup

# Start the application
bundle exec rails server
```

The application will be available at [http://localhost:3000](http://localhost:3000)

**Note**: Make sure you have the prerequisites installed first (see "Prerequisites" section above).

### Alternative: Automated Setup Script
If you prefer the traditional Rails setup script:

```bash
# Prerequisites: rbenv, PostgreSQL, and Homebrew must be installed first
./bin/setup
```

### Manual Setup (Step by Step)
If you prefer to set up manually or need to troubleshoot:

#### 1. Clone the Repository
```bash
git clone https://github.com/odontome/app.git
cd app
```

#### 2. Install Dependencies
```bash
# Install Ruby gems
gem install bundler
bundle install

# Install JavaScript dependencies
yarn install
```

#### 3. Configure Environment Variables
Copy the environment template and configure your local settings:

```bash
# Copy the example file
cp .env.example .env

# Generate a secret key and add it to .env
echo "SECRET_KEY_BASE=$(bundle exec rails secret)" >> .env
```

For more environment variable options, see the "Environment Variables" section below.

#### 4. Database Setup
```bash
# Create the databases
bundle exec rails db:create

# Run migrations
bundle exec rails db:migrate

# Seed the database with initial data (if available)
bundle exec rails db:seed
```

#### 5. Compile Assets
```bash
# Compile JavaScript and CSS assets for production
bundle exec rails assets:precompile

# For development, compile once
./bin/webpack
```

#### 6. Start the Application

```bash
# Start the Rails server
bundle exec rails server

# Or using the bin script
./bin/rails server
```

The application will be available at [http://localhost:3000](http://localhost:3000)

## Running Tests

```bash
# Run the test suite
bundle exec rails test

# Run with verbose output
bundle exec rails test -v

# Run specific test files
bundle exec rails test test/models/user_test.rb
```

## Asset Development

For frontend development with automatic recompilation:

```bash
# In one terminal, start the Rails server
bundle exec rails server

# In another terminal, start Webpack dev server for auto-recompilation
./bin/webpack-dev-server
```

Or compile assets manually when needed:
```bash
# Compile once
./bin/webpack

# Watch for changes and recompile automatically
./bin/webpack --watch
```

## Deployment

Deploys automatically every commit on the `master` branch to the staging environment. It's important to keep the branch in a deployable state.

## Environment Variables

### Required for Production
Include the following environment variables in your production instance:

| Key                      | Description                                       | Required | Local Dev |
| ------------------------ | ------------------------------------------------- | -------- | --------- |
| `SECRET_KEY_BASE`        | Rails secret key, used to secure your application | Yes      | Yes       |
| `STRIPE_PUBLISHABLE_KEY` | Used by Stripe for subscription management        | Yes      | Optional* |
| `STRIPE_SECRET_KEY`      | See above                                         | Yes      | Optional* |
| `STRIPE_WEBHOOK_SECRET`  | Used by Stripe to authenticate your requests      | Yes      | Optional* |
| `STRIPE_PRICE_ID`        | Used by Stripe for the subscription price         | Yes      | Optional* |
| `SENDGRID_API_KEY`       | Used by Sendgrid in order to use Rails Mailers    | Yes      | Optional* |
| `SENDGRID_DOMAIN`        | See above                                         | Yes      | Optional* |
| `SENDGRID_USERNAME`      | See above                                         | Yes      | Optional* |
| `SENDGRID_PASSWORD`      | See above                                         | Yes      | Optional* |
| `BUGSNAG_API_KEY`        | Used by Bugsnag for error tracking                | No       | No        |
| `DATABASE_URL`           | PostgreSQL connection string                       | Yes**    | Optional  |

\* For local development, you can skip payment and email functionality  
\** Required for production; for local development, database.yml is used

### Setting Up Environment Variables Locally

#### Using .env file (Recommended)
```bash
# Copy the example file
cp .env.example .env

# Edit .env with your values
# Add at minimum:
SECRET_KEY_BASE=$(bundle exec rails secret)
```

The .env file will be automatically loaded when you start the Rails application.

#### Option 2: Export in your shell
Add to your `~/.zshrc` or `~/.bash_profile`:

```bash
export SECRET_KEY_BASE="your_generated_secret_key_here"
export DATABASE_URL="postgresql://localhost/odonto_development"

# Reload your shell configuration
source ~/.zshrc
```

#### Option 3: Set variables when running commands
```bash
SECRET_KEY_BASE=your_key_here bundle exec rails server

# Or create a simple script
echo '#!/bin/bash
export SECRET_KEY_BASE="your_generated_secret_key_here"
export DATABASE_URL="postgresql://localhost/odonto_development"
bundle exec rails server' > start_server.sh
chmod +x start_server.sh
./start_server.sh
```

### Generating a Secret Key
```bash
# Generate a new secret key
bundle exec rails secret
```

## Setting up Scheduler

### For Production
Add all the jobs in `/lib/tasks/odontome.rake` to your scheduler:

- `odontome:send_appointment_reminder_notifications` - Every hour
- `odontome:send_appointment_scheduled_notifications` - Every 5 minutes  
- `odontome:delete_practices_cancelled_a_while_ago` - Daily
- `odontome:send_todays_appointments_to_doctors` - Daily at 7 AM
- `odontome:send_birthday_wishes_to_patients` - Daily at 3 PM
- `odontome:send_appointment_review_to_patients` - Every hour

### For Local Development
You can run these tasks manually for testing:

```bash
# Test a specific task
bundle exec rake odontome:send_appointment_reminder_notifications

# See all available tasks
bundle exec rake -T odontome
```

## Setting up Stripe

Watch all the events in `/app/controllers/api/webhooks/stripe_controller.rb` in the developer section of your Stripe dashboard.

For local development, you can use Stripe's test keys and webhook forwarding:

```bash
# Install Stripe CLI
brew install stripe/stripe-cli/stripe

# Login to your Stripe account
stripe login

# Forward webhooks to your local server
stripe listen --forward-to localhost:3000/api/webhooks/stripe
```

## Troubleshooting (macOS)

### Common Issues and Solutions

#### PostgreSQL Connection Issues
```bash
# If PostgreSQL isn't running
brew services start postgresql@14

# If you get permission errors
createuser -s $(whoami)

# If database doesn't exist
bundle exec rails db:create
```

#### Gem Installation Issues
```bash
# If you get permission errors
gem install bundler --user-install

# If pg gem fails to install
gem install pg -- --with-pg-config=/opt/homebrew/bin/pg_config
# Or for Intel Macs:
gem install pg -- --with-pg-config=/usr/local/bin/pg_config
```

#### Node.js/Yarn Issues
```bash
# If yarn install fails
yarn install --network-timeout 100000

# If webpack compilation fails
yarn cache clean
yarn install
```

#### M1/M2 Mac Specific Issues
```bash
# If you encounter native gem compilation issues
bundle config build.pg --with-pg-config=/opt/homebrew/bin/pg_config
bundle install

# For other native gems
arch -arm64 bundle install
```

#### Rails Server Issues
```bash
# If port 3000 is already in use
bundle exec rails server -p 3001

# If you get "Spring is running" issues
bundle exec spring stop
bundle exec rails server
```

#### Asset Compilation Issues
```bash
# Clear precompiled assets
bundle exec rails assets:clobber

# Recompile assets
bundle exec rails assets:precompile

# For development mode, clear webpack cache
rm -rf public/packs
rm -rf tmp/cache/webpacker
./bin/webpack

# If webpack-dev-server has issues
./bin/webpack-dev-server --mode=development
```

### Getting Help

If you encounter issues not covered here:

1. Check the Rails logs: `tail -f log/development.log`
2. Check that all prerequisites are properly installed
3. Ensure all environment variables are set correctly
4. Try restarting your development server
5. Clear browser cache and cookies

### Useful Development Commands

```bash
# Rails console
bundle exec rails console

# Database console
bundle exec rails dbconsole

# View routes
bundle exec rails routes

# Generate new secret key
bundle exec rails secret

# Run specific tests
bundle exec rails test test/models/

# Check code style (if RuboCop is configured)
bundle exec rubocop
```
