# Paper Trail Auditing Implementation

This document describes the Paper Trail auditing implementation added to the Odontome Rails application.

## Overview

Paper Trail is a Ruby gem that tracks changes to your models over time. It automatically creates a version history whenever a model is created, updated, or destroyed.

## Models with Auditing

The following models have been configured with Paper Trail auditing:

- **Patient** - Tracks changes to patient information
- **User** - Tracks changes to user accounts and profile data
- **Practice** - Tracks changes to practice settings and information
- **Appointment** - Tracks changes to appointment scheduling and status

## Configuration

Paper Trail is configured in `/config/initializers/paper_trail.rb`:

```ruby
PaperTrail.config.version_limit = 25
```

This limits each model to storing a maximum of 25 versions to prevent unbounded growth.

## Database Schema

Paper Trail creates a `versions` table with the following columns:

- `whodunnit` - Records who made the change (currently nil, can be configured later)
- `created_at` - When the change occurred
- `item_id` - ID of the changed record
- `item_type` - Class name of the changed model
- `event` - Type of change: 'create', 'update', or 'destroy'
- `object` - YAML-serialized previous state of the record (for updates/destroys)

## Usage Examples

### Accessing Version History

```ruby
# Get all versions for a patient
patient = Patient.find(1)
versions = patient.versions

# Get the latest version
latest_version = patient.versions.last

# Check what type of change it was
puts latest_version.event  # 'create', 'update', or 'destroy'
```

### Querying All Versions

```ruby
# Find all versions for a specific model type
patient_versions = PaperTrail::Version.where(item_type: 'Patient')

# Find all versions created in the last hour
recent_versions = PaperTrail::Version.where('created_at > ?', 1.hour.ago)
```

## Testing

Comprehensive tests have been added in `test/unit/paper_trail_test.rb` that verify:

- Versions are created for create, update, and destroy events
- Version limits are respected
- Version data is properly stored
- All configured models track changes correctly

## Benefits

1. **Audit Trail** - Complete history of who changed what and when
2. **Compliance** - Helps meet regulatory requirements for data tracking
3. **Debugging** - Easy to see how data evolved over time
4. **Recovery** - Ability to see previous states of records

## Future Enhancements

- Configure `whodunnit` to track which user made changes
- Add admin interface to view audit trails
- Set up retention policies for old versions
- Add change notifications for critical models