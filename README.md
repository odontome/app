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

### 3. PostgreSQL

```bash
# Install PostgreSQL
brew install postgresql@14

# Start PostgreSQL service
brew services start postgresql@14

# Stop PostgreSQL service
brew services stop postgresql@14
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

| Key                      | Description                                       | Required | Local Dev  |
| ------------------------ | ------------------------------------------------- | -------- | ---------- |
| `SECRET_KEY_BASE`        | Rails secret key, used to secure your application | Yes      | Yes        |
| `STRIPE_PUBLISHABLE_KEY` | Used by Stripe for subscription management        | Yes      | Optional\* |
| `STRIPE_SECRET_KEY`      | See above                                         | Yes      | Optional\* |
| `STRIPE_WEBHOOK_SECRET`  | Used by Stripe to authenticate your requests      | Yes      | Optional\* |
| `STRIPE_PRICE_ID`        | Used by Stripe for the subscription price         | Yes      | Optional\* |
| `SENDGRID_API_KEY`       | Used by Sendgrid in order to use Rails Mailers    | Yes      | Optional\* |
| `SENDGRID_DOMAIN`        | See above                                         | Yes      | Optional\* |
| `SENDGRID_USERNAME`      | See above                                         | Yes      | Optional\* |
| `SENDGRID_PASSWORD`      | See above                                         | Yes      | Optional\* |
| `BUGSNAG_API_KEY`        | Used by Bugsnag for error tracking                | No       | No         |
| `DATABASE_URL`           | PostgreSQL connection string                      | Yes\*\*  | Optional   |

\* For local development, you can skip payment and email functionality  
\*\* Required for production; for local development, database.yml is used

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

#### Notification Tasks
- `odontome:send_appointment_reminder_notifications` - Every hour
  - Sends reminders to patients 48 hours before their appointments
- `odontome:send_appointment_scheduled_notifications` - Every 5 minutes
  - Notifies patients when new appointments are scheduled
- `odontome:send_todays_appointments_to_doctors` - Daily at 7 AM
  - Sends doctors their daily appointment schedule
- `odontome:send_birthday_wishes_to_patients` - Daily at 3 PM
  - Sends birthday wishes to patients in their timezone
- `odontome:send_appointment_review_to_patients` - Every hour
  - Requests reviews from patients after appointments
- `odontome:send_six_month_checkup_reminders` - Every hour (targets 10 AM local time per practice)
  - Reminds patients about their 6-month dental checkups

#### Maintenance Tasks
- `odontome:cleanup_audit_logs` - Daily
  - Removes audit logs older than 30 days to prevent database bloat
- `odontome:cleanup_old_practices` - Daily
  - Deletes practices older than 7 days with 0 patients
- `odontome:mark_inactive_practices_for_cancellation` - Daily
  - Marks practices for cancellation where no user has logged in for 60+ days (excludes active subscriptions)
- `odontome:delete_practices_cancelled_a_while_ago` - Daily
  - Permanently deletes practices cancelled more than 15 days ago

### For Local Development

You can run these tasks manually for testing:

```bash
# Test notification tasks
bundle exec rake odontome:send_appointment_reminder_notifications
bundle exec rake odontome:send_six_month_checkup_reminders

# Test maintenance tasks
bundle exec rake odontome:cleanup_audit_logs
bundle exec rake odontome:cleanup_old_practices
bundle exec rake odontome:mark_inactive_practices_for_cancellation

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

### Stripe Connect Setup

The application also supports Stripe Connect for enabling practices to accept payments directly from patients:

1. **Platform Account**: Set up your main Stripe account for the platform
2. **Connect Application**: Create a Connect application in your Stripe dashboard

**Connect Features:**

- Express accounts for quick practice onboarding
- Application fees (configurable platform commission)
- Automatic transfers to practice bank accounts
- Real-time payment processing
- Webhook-based account status monitoring

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
