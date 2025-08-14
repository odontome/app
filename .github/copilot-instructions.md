# GitHub Copilot Instructions for Odontome Rails 7 Application

This document provides comprehensive coding guidelines and best practices for the Odontome dental practice management system built with Ruby on Rails 7. Follow these patterns to maintain consistency, security, and maintainability.

## 🚨 CORE PRINCIPLE: SIMPLICITY IS A HARD REQUIREMENT

**SIMPLICITY MUST BE A HARD REQUIREMENT FOR EVERYTHING WE BUILD.**

- Favor simple, straightforward solutions over clever or complex ones
- Avoid unnecessary features, options, or configurations
- Write code that is easy to understand and maintain
- Remove complexity wherever possible
- If in doubt, choose the simpler approach

## Core Rails 7 Principles

### 1. Always Use Frozen String Literals

All Ruby files must start with the frozen string literal comment:

```ruby
# frozen_string_literal: true

class Patient < ApplicationRecord
  # ... rest of class
end
```

**Why**: Improves performance and prevents string mutation bugs.

### 2. Favor Simplicity and Readability

Write code that is easy to understand and maintain. Prefer explicit over clever.

```ruby
# Good - Simple and clear
def fullname
  [firstname, lastname].join(' ')
end

# Avoid - Too clever
def fullname
  [firstname, lastname].compact.join(' ').strip
end
```

## Model Best Practices

### 1. Consistent Model Structure

Follow this order in models (as seen in `app/models/patient.rb`):

```ruby
class Patient < ApplicationRecord
  # concerns first
  include Initials

  # associations
  has_many :appointments, dependent: :delete_all
  belongs_to :practice, counter_cache: true

  # scopes
  scope :with_practice, lambda { |practice_id|
    where('patients.practice_id = ? ', practice_id).order('firstname')
  }

  # validations
  validates_presence_of :practice_id, :firstname, :lastname, :date_of_birth
  validates_length_of :firstname, within: 1..25

  # callbacks
  before_save :squish_whitespace

  # public methods
  def fullname
    [firstname, lastname].join(' ')
  end

  # class methods
  def self.find_or_create_from(patient_id_or_name, practice_id)
    # implementation
  end

  private

  # private methods
  def squish_whitespace
    firstname&.squish!
    lastname&.squish!
  end
end
```

### 2. Use Counter Caches for Performance

When you have `has_many` relationships that need counting:

```ruby
# In Practice model
has_many :patients

# In Patient model
belongs_to :practice, counter_cache: true
```

### 3. Secure Scopes with Proper SQL Escaping

Always escape user input to prevent SQL injection:

```ruby
scope :search, lambda { |q|
  escaped_q = ActiveRecord::Base.sanitize_sql_like(q)
  where("uid ILIKE ? OR (firstname || ' ' || lastname) ILIKE ?", "%#{escaped_q}%", "%#{escaped_q}%")
}
```

### 4. Use Includes to Prevent N+1 Queries

When accessing related data:

```ruby
scope :find_between, lambda { |starts_at, ends_at|
  includes(:doctor, :patient)
    .where('appointments.starts_at > ? AND appointments.ends_at < ?', starts_at, ends_at)
    .order('appointments.starts_at')
}
```

### 5. Optimize Queries with Select

Only fetch needed columns for performance:

```ruby
scope :anything_with_letter, lambda { |letter|
  select('firstname, lastname, uid, id, date_of_birth, allergies, email, updated_at')
    .where('LOWER(SUBSTRING(firstname, 1, 1)) = ?', letter.downcase)
}
```

### 6. Use Concerns for Shared Behavior

Create reusable modules for shared functionality:

```ruby
# app/models/concerns/initials.rb
module Initials
  extend ActiveSupport::Concern

  def initials
    "#{firstname.chars.first&.upcase}#{lastname.chars.first&.upcase}"
  end
end
```

## Controller Best Practices

### 1. Consistent Controller Structure

Follow this pattern (as seen in `app/controllers/patients_controller.rb`):

```ruby
class PatientsController < ApplicationController
  # before_actions first
  before_action :require_user
  before_action :require_practice_admin, only: [:destroy]

  # actions in RESTful order
  def index
    # implementation
  end

  def show
    # implementation
  end

  def new
    # implementation
  end

  def create
    # implementation
  end

  private

  # strong parameters
  def patient_params
    params.require(:patient).permit(:uid, :firstname, :lastname, :date_of_birth)
  end
end
```

### 2. Always Use Strong Parameters

Never permit all parameters:

```ruby
# Good
def patient_params
  params.require(:patient).permit(:uid, :firstname, :lastname, :date_of_birth,
                                 :past_illnesses, :surgeries, :medications)
end

# Never do this
def patient_params
  params.require(:patient).permit!
end
```

### 3. Scope Data to Current User's Practice

Always scope data to prevent unauthorized access:

```ruby
def show
  @patient = Patient.with_practice(current_user.practice_id).find(params[:id])
end

def index
  @patients = Patient.anything_with_letter(params[:letter])
                    .with_practice(current_user.practice_id)
end
```

### 4. Use Proper Authorization Filters

Implement granular authorization:

```ruby
class PatientsController < ApplicationController
  before_action :require_user
  before_action :require_practice_admin, only: [:destroy]
end
```

### 5. Handle Different Response Formats

Support multiple formats when needed:

```ruby
def index
  respond_to do |format|
    format.html # index.html
    format.json {
      render json: @patients, methods: :fullname
    }
  end
end
```

## Security Best Practices

### 1. CSRF Protection

Always enabled in ApplicationController:

```ruby
class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception
end
```

### 2. Authentication and Authorization

Implement proper filters as shown in ApplicationController:

```ruby
def require_user
  unless current_user
    store_location
    flash[:notice] = t :not_logged_in
    redirect_to signin_path
    false
  end
end

def require_practice_admin
  unless user_is_admin?(current_user)
    redirect_back_or_default('/401', I18n.t(:admin_credentials_required))
    false
  end
end
```

### 3. Session Management

Clear sessions on security-relevant actions:

```ruby
def check_account_status
  if current_user && (current_user.practice.status == 'cancelled')
    session.clear
    redirect_to signin_url, alert: I18n.t(:account_cancelled)
  end
end
```

## Performance Optimization

### 1. Database Indexing

Ensure proper indexes for frequently queried fields:

- Foreign keys (practice_id, patient_id, etc.)
- Search fields (firstname, lastname, email)
- Timestamp fields used in ordering

### 2. Eager Loading

Use `includes` to prevent N+1 queries:

```ruby
@patient_notes = @patient.notes.includes(:user).order('created_at DESC')
```

### 3. Limit Large Queries

Always limit search results:

```ruby
scope :search, lambda { |q|
  # ... where clauses ...
  .limit(25)
  .order('firstname')
}
```

## Validation Best Practices

### 1. Use Appropriate Validation Types

Be specific with validations:

```ruby
validates_presence_of :practice_id, :firstname, :lastname, :date_of_birth
validates_uniqueness_of :uid, scope: :practice_id, allow_nil: true, allow_blank: true
validates_numericality_of :cigarettes_per_day, only_integer: true,
                         greater_than_or_equal_to: 0, allow_blank: true
validates_length_of :firstname, within: 1..25
validates :email, format: { with: /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z/i },
                 allow_nil: true, allow_blank: true
```

### 2. Use Scoped Uniqueness

When uniqueness should be scoped to a practice:

```ruby
validates_uniqueness_of :email, scope: :practice_id, allow_nil: true, allow_blank: true
```

## Internationalization (i18n)

### 1. Always Use i18n Keys

Never hardcode user-facing text:

```ruby
# Good
flash[:notice] = I18n.t(:patient_created_success_message)

# Bad
flash[:notice] = "Patient created successfully"
```

### 2. Support Multiple Locales

Configure available locales in application.rb:

```ruby
config.i18n.available_locales = %w[es en]
config.i18n.enforce_available_locales = false
```

## Testing Guidelines

### 1. Write Focused Tests

Test one thing at a time and use descriptive names:

```ruby
# Good test structure
test "should create patient with valid attributes" do
  patient = Patient.new(valid_patient_attributes)
  assert patient.save
end

test "should not save patient without firstname" do
  patient = Patient.new(valid_patient_attributes.except(:firstname))
  assert_not patient.save
end
```

### 2. Use Fixtures or Factories

Prefer fixtures for simple, stable test data.

## Error Handling

### 1. Graceful Error Handling

Handle errors gracefully and provide meaningful feedback:

```ruby
def find_or_create_from(patient_id_or_name, practice_id)
  begin
    patient_double_check = Patient.find patient_id_or_name
  rescue ActiveRecord::RecordNotFound
    patient_id_or_name = nil
  end
end
```

### 2. Use Flash Messages Appropriately

Provide clear feedback to users:

```ruby
if @patient.save
  redirect_to(@patient, notice: I18n.t(:patient_created_success_message))
else
  render action: 'new'
end
```

## Routing Best Practices

### 1. Use RESTful Routes

Prefer RESTful conventions:

```ruby
resources :patients do
  resources :notes
  resources :balances
end
```

### 2. Namespace Related Routes

Group related functionality:

```ruby
namespace :api do
  namespace :webhooks do
    post "/stripe", to: "stripe#event"
  end
end
```

## Code Organization

### 1. Use Helper Methods

Extract complex logic to helper methods:

```ruby
helper_method :current_session, :current_user, :user_is_admin?
```

### 2. Keep Methods Small

Prefer small, focused methods:

```ruby
# Good - single responsibility
def age
  if !missing_info?
    (Time.now.year - date_of_birth.year) - (Time.now.yday < date_of_birth.yday ? 1 : 0)
  else
    0
  end
end

def missing_info?
  date_of_birth.nil?
end
```

## Common Patterns in This Application

### 1. Practice Scoping

Always scope data to the current user's practice:

```ruby
scope :with_practice, lambda { |practice_id|
  where('patients.practice_id = ? ', practice_id).order('firstname')
}
```

### 2. Safe Navigation

Use safe navigation operators for potentially nil objects:

```ruby
def initials
  "#{firstname.chars.first&.upcase}#{lastname.chars.first&.upcase}"
end
```

### 3. String Cleaning

Clean user input consistently:

```ruby
before_save :squish_whitespace

private

def squish_whitespace
  firstname&.squish!
  lastname&.squish!
end
```

## What to Avoid

### 1. Don't Use Raw SQL Unless Necessary

Prefer ActiveRecord methods:

```ruby
# Good
Patient.where(practice_id: practice.id)

# Avoid unless necessary
Patient.where("practice_id = #{practice.id}")
```

### 2. Don't Skip Validations Without Good Reason

Only skip validations when absolutely necessary:

```ruby
# Only when importing data or in very specific scenarios
patient.save!(validate: false)
```

### 3. Don't Put Business Logic in Views

Keep views simple and logic in models/controllers.

### 4. Don't Use Global Variables

Use proper Rails patterns instead of global state.

---

**Remember**: Favor simplicity, maintainability, and security over cleverness. When in doubt, choose the more explicit and readable approach.
