# Patient Listing Redesign — V1 Spec

## Problem

The patients page is a passive alphabetical directory. Front desk staff open it every morning but it doesn't answer their first question: "Who's coming in today?" The page should be the pulse of the clinic, not a phone book.

## Design Decisions

- **Segment pills** (Tabler `nav-pills`) over tabs — lighter cognitive load, feels like filtering not navigating
- **"Today" as the default** — the most useful view for the morning workflow
- **Drop `updated_at`** from all patient rows — system field, no clinical value
- **Keep existing infrastructure** — global nav search, A-Z picker, cursor pagination, sort toggles all stay on "All patients"
- **Tabler components only** — no custom styling
- **Rails conventions only** — model scopes, controller private methods, no service objects

## Segments

### Today (default)

Shows patients with confirmed or waiting-room appointments today, sorted by appointment start time.

**Columns:**

| Column | Source | Example |
|--------|--------|---------|
| Time | `appointments.starts_at` + duration from `ends_at - starts_at` | "10:30 AM (30 min)" |
| Patient | `patients.firstname`, `patients.lastname`, avatar | María García |
| Chart # | `patients.uid` | 1234 |
| Doctor | `doctors.firstname` + `doctors.lastname` | Dr. López |
| Status | `appointments.status` | Confirmed / Waiting |
| Actions | Existing dropdown | View, Edit, Create payment, Delete |

**Query:** Appointments for today (practice timezone), with status in `[confirmed, confirmed_and_waiting]` only (explicit allowlist, not exclusion-based — new statuses should not appear here by default). Joined to patients and doctors, ordered by `starts_at ASC`.

**No pagination needed** — a clinic won't have hundreds of appointments in a single day.

**No A-Z picker** — irrelevant when viewing by appointment time.

**Empty state:** Friendly message: "No appointments today" with a link to "View all patients". Uses the same warm, jargon-free tone as the rest of the app.

### All patients

The current listing, with these changes:

- **Remove** the `updated_at` column
- **Keep** all existing functionality: A-Z letter picker, cursor-based pagination, sort toggles (name, last visit), "Load more patients" button
- **Keep** the `new_this_week` segment link from the KPI dashboard (it bypasses pills and shows the filtered list directly, as it does today)

**Columns:**

| Column | Source | Example |
|--------|--------|---------|
| Name | `patients.firstname`, `patients.lastname`, avatar, email | María García |
| Chart # | `patients.uid` | 1234 |
| Status | `patient.missing_info?` | Active / Incomplete |
| Last visit | LATERAL JOIN on appointments | "12 Jan" or "Never" |
| Actions | Existing dropdown | View, Edit, Create payment, Delete |

## URL Structure

| URL | Behavior |
|-----|----------|
| `/patients` | Default: "Today" segment |
| `/patients?segment=today` | Explicit "Today" segment |
| `/patients?segment=all` | "All patients" segment |
| `/patients?letter=A` | "All patients" with letter A selected |
| `/patients?letter=A&sort=last_visit&direction=desc` | "All patients" sorted by last visit |
| `/patients?segment=new_this_week` | Existing KPI link, works as before |
| `/patients?term=garcia` | Search results (no pills shown, works as before) |

When `letter`, `sort`, or `cursor` params are present without an explicit segment, infer "All patients". When `term` is present, show search results without segment pills (current behavior).

## Pill Counts

The "Today" pill shows a count badge: `Today (5)`. This count comes from a lightweight query: count of today's confirmed + waiting-room appointments for the practice.

The "All patients" pill does **not** show a count — counting all patients on every page load is wasteful and the number isn't actionable.

## I18n

New keys needed in all three locales (en, es, pt):

| Key | en | es | pt |
|-----|----|----|-----|
| `patients_segment_today` | Today | Hoy | Hoje |
| `patients_segment_all` | All patients | Todos los pacientes | Todos os pacientes |
| `patients_today_empty` | No appointments today | Sin citas para hoy | Sem consultas hoje |
| `patients_today_empty_hint` | View all patients | Ver todos los pacientes | Ver todos os pacientes |
| `appointment_time_duration` | "%{time} (%{duration} min)" | "%{time} (%{duration} min)" | "%{time} (%{duration} min)" |
| `appointment_status_confirmed` | Confirmed | Confirmada | Confirmada |
| `appointment_status_waiting` | In waiting room | En sala de espera | Na sala de espera |

## Controller Changes

**`PatientsController#index`:**

Restructure the `index` action with a clear segment routing:

1. If `term` present → search mode (unchanged, no pills, sets `@patients`)
2. If `segment=new_this_week` → existing KPI filter (unchanged, no pills, sets `@patients`)
3. If `segment=all` or any letter/sort/cursor params present → "All patients" (existing `resolve_letter_context`, sets `@patients`, `@segment = 'all'`)
4. Otherwise (no params, or `segment=today`) → "Today" segment (new code path, sets `@appointments`, `@segment = 'today'`)

**Instance variables by segment:**
- **Today:** `@segment = 'today'`, `@appointments` (list of Appointment records with eager-loaded patient and doctor), `@today_count` (for pill badge). Note: the Today segment uses `@appointments`, not `@patients`, because the primary object is the appointment (with its time, doctor, and status).
- **All patients:** `@segment = 'all'`, `@patients`, `@current_letter`, `@sort_column`, `@sort_direction`, `@next_cursor` (all existing)
- **Search / new_this_week:** `@segment = nil` (no pills shown), `@patients` (existing)

The pill count for "Today" can be derived from `@appointments.size` when on the Today segment, or from a lightweight count query when on the "All patients" segment. Since the count is just a number in a pill badge, a single `COUNT(*)` query with the same filters is sufficient.

**Existing test impact:** The existing `'should get index'` test does `GET /patients` with no params and expects letter-based results. After this change, that request hits the Today segment instead. Update this test to either pass `segment=all` or assert against the new Today behavior.

**Use `travel_to`** in timezone-sensitive tests (test 4) to freeze time and make assertions deterministic.

**New model scope on Appointment:**

```ruby
# Appointment.status keys: :confirmed => 'confirmed',
#                          :waiting_room => 'confirmed_and_waiting',
#                          :cancelled => 'cancelled'
scope :today_for_practice, ->(practice_id, timezone) {
  tz = ActiveSupport::TimeZone[timezone] || Time.zone
  today_start = tz.now.beginning_of_day
  today_end = tz.now.end_of_day

  eager_load(:patient, :doctor)
    .where(patients: { practice_id: practice_id })
    .where(status: [status[:confirmed], status[:waiting_room]])
    .where(starts_at: today_start..today_end)
    .order(:starts_at)
}
```

Notes:
- `practice_id` lives on `patients`, not `appointments` — the join through `:patient` is required for practice scoping.
- Uses `eager_load` instead of `joins` to avoid N+1 queries when the view accesses `appointment.patient` and `appointment.doctor` attributes.

## View Changes

**`app/views/patients/index.html.erb`:**

1. Add Tabler `nav-pills` above the card, conditionally shown when not in search mode
2. Render the active pill based on `@segment`
3. Conditionally render the appropriate table header (today columns vs. all-patients columns)
4. Conditionally show A-Z picker only for the "all" segment

**New partial: `app/views/patients/_today_patient.html.erb`:**

A separate partial for the "Today" row, since the columns are different from the "All patients" row. Receives both the appointment and the patient.

**Existing `_patient.html.erb`:**

Remove the `updated_at` column. No other changes.

**Existing `_letter_pagination.html.erb`:**

No changes. Only rendered for the "all" segment.

**Existing `index.js.erb`:**

The `format.js` response (used by "Load more patients") is only relevant for the "All patients" segment. The Today segment has no pagination and no JS response path. No changes needed to `index.js.erb` — the JS path is only triggered by cursor-based pagination links, which only exist in the "all" segment.

**Important: `sortable_listing` guard must change.**

The current view uses `params[:term].nil? && params[:segment].nil?` to decide whether to show sort links and the A-Z picker. After this redesign, visiting `/patients` with no params will be the Today segment, where sort links and the A-Z picker should NOT appear. Change this guard to `@segment == 'all'` instead of relying on the absence of params.

## Testing

**Controller tests (`test/functional/patients_controller_test.rb`):**

1. `test 'index defaults to today segment'` — GET `/patients` with no params shows today's appointments
2. `test 'today segment shows only todays appointments'` — create appointments for today and yesterday, verify only today's appear
3. `test 'today segment excludes cancelled appointments'` — cancelled appointments don't show
4. `test 'today segment respects practice timezone'` — appointment at 11 PM in practice TZ that's technically tomorrow in UTC still shows
5. `test 'today segment empty state'` — no appointments today returns empty patients list
6. `test 'all segment preserves existing behavior'` — GET with `segment=all` works like the current default
7. `test 'segment pills not shown during search'` — GET with `term` param doesn't set segment

**Helper tests (`test/unit/patients_helper_test.rb`):**

1. Test pill rendering with correct active state
2. Test count badge on Today pill

## Out of Scope (V2)

- "Needs follow-up" segment (patients with no visit in 6+ months and no future appointment)
- Inline check-in actions (mark as arrived/waiting from the Today view)
- Outstanding balance indicator on Today rows
- Mobile-optimized A-Z picker (collapsible on small screens)
- Birthday this week segment
