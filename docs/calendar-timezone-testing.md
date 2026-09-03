# Calendar timezone regression coverage

All calendar times are intended to be practice-local, independent of a staff
member's device timezone. The Rails tests cover server round trips; browser
behavior and the legacy calendar's remaining limits are documented separately.
FullCalendar remains **1.6.4**, unchanged; an upgrade was explicitly deferred.

## Passing regression gates

Run with the project's existing Ruby 3.2.3 / Rails / Minitest setup:

```sh
bin/rails test test/functional/calendar_timezone_test.rb
bin/rails test
```

There is no additional test runtime or framework. The custom JavaScript runner
and Node CI step have been removed. These Ruby tests do not execute browser
JavaScript and must not be described as equivalent browser coverage.

Full Rails suite before PR: **634 tests, 3,869 assertions, zero failures,
errors, or skips**.

- `calendar_timezone_test.rb`: 28 tests, 940 assertions. Both admin and user
  roles; real test-database create, move, resize, repeated schedule reads, and
  unrelated edits that must preserve stored timestamps. Twelve explicit
  zone/date/offset cases include northern/southern DST, Lord Howe's half-hour
  transition, Kathmandu's quarter-hour offset, and opposite sides of the date
  line at New Year. Four additional cases move 9 AM appointments across DST.
- Prior signed-in visual check: the existing September 3 appointment was visible
  at 8–9 AM. The timezone label has since been removed at the user's request;
  the underlying timezone handling is unchanged. No real appointment was changed.

## Known unresolved issue: viewer DST gaps

The earlier JavaScript diagnostic exposed the cases below. Removing that
custom runner does not fix the underlying issue. They remain browser-verification
targets for the separately deferred calendar work.

FullCalendar's `ignoreTimezone` preserves ISO wall-clock fields by constructing
a native browser-local `Date`. A valid practice-local time can be nonexistent
in the viewer's timezone. Native Date then normalizes it into a different hour:

| Cancún practice time | Viewer timezone | Incorrect displayed time |
| --- | --- | --- |
| March 8, 2026, 02:30 | America/Los_Angeles or America/New_York | 03:30 |
| March 29, 2026, 01:30 | Europe/London | 02:30 |
| October 4, 2026, 02:30 | Australia/Sydney | 03:30 |
| October 4, 2026, 02:00 | Australia/Lord_Howe | 02:30 |

These examples are outside the current demo calendar's 08:00–20:00 hours, but
the application permits earlier opening hours. Passing daytime tests must not
be represented as a guarantee covering every time worldwide. The earlier check
demonstrated a display/parser error, not an observed production database write.

## Still outside the verified guarantee

- Interactive create/drag/resize and reloads in multiple actual browser engines
  and device timezones; Rails request tests do not cover pointer handling,
  client-side payload construction, or pixel placement.
- The legacy Today button and today's highlighting use the browser clock,
  unlike the initial practice-local date passed by Rails. Midnight and long-open
  tabs need explicit navigation tests when calendar date handling is revisited.
- Missing/repeated times in the practice's own DST transition hour require an
  explicit product rule; daytime create/move tests do not settle that ambiguity.

The earlier passing Rails suite did not establish worldwide timezone safety.
Do not make that release claim until these gaps have been addressed and tested.
