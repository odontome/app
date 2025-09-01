# Announcements Feature Migration to Database Storage

This migration updates the announcements dismissal feature from session-based storage to database-based storage for better persistence and user experience.

## Changes Made

### 1. Database Changes
- **New Model**: `DismissedAnnouncement` 
  - Stores user-specific announcement dismissals
  - Foreign key relationship to `users` table
  - Unique constraint on `(user_id, announcement_version)`

- **New Migration**: `CreateDismissedAnnouncements`
  - Creates `dismissed_announcements` table
  - Adds proper indexes for performance

### 2. Code Changes

#### Model Updates
- **User Model**: Added `has_many :dismissed_announcements` association
- **DismissedAnnouncement Model**: New model with validations and scopes

#### Controller Updates  
- **AnnouncementsController#dismiss**: Now creates database records instead of session storage
- Uses `find_or_create_by` to prevent duplicates
- Maintains same API for frontend compatibility

#### Helper Updates
- **ApplicationHelper#active_announcements**: Now queries database for dismissed announcements
- Handles both authenticated and unauthenticated users
- Uses efficient `pluck` query for performance

### 3. Test Updates
- Updated existing controller tests to verify database storage
- Added comprehensive model tests for validations and associations
- Added helper tests for various user authentication states

## Migration Instructions

1. **Run the migration**:
   ```bash
   rails db:migrate
   ```

2. **Optional: Migrate existing session data** (if needed):
   Since session data is temporary and user-specific, existing dismissed announcements in sessions will naturally expire and users will see announcements again. No special migration of session data is needed.

## Benefits

- **Persistence**: Dismissed announcements persist across browser sessions
- **User-specific**: Each user has their own dismissal history
- **Performance**: Database queries are more efficient than session storage for this use case
- **Scalability**: No session bloat from storing announcement data
- **Analytics**: Ability to track announcement engagement if needed in future

## Backward Compatibility

- Frontend JavaScript code requires no changes
- API endpoints remain the same  
- Existing functionality is preserved

## Database Schema

```sql
CREATE TABLE dismissed_announcements (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id),
  announcement_version INTEGER NOT NULL,
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);

CREATE UNIQUE INDEX index_dismissed_announcements_on_user_and_version 
ON dismissed_announcements (user_id, announcement_version);
```