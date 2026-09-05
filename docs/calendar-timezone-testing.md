# Calendar timezone regression coverage

All calendar times are intended to be practice-local, independent of a staff
member's device timezone. The browser calendar uses FullCalendar 6.1.18 from
Tabler's supported integration.

FullCalendar is configured with `timeZone: "UTC"` as a neutral wall-clock
carrier. The calendar endpoint's opt-in `wall_clock=1` response returns the
practice's displayed date and time without an offset. JavaScript can therefore
use native `Date` objects without applying the viewer's timezone or DST rules.
Rails remains responsible for interpreting submitted wall-clock fields in the
practice timezone. The default JSON endpoint retains offset-bearing timestamps
for existing clients.

## Regression gates

Run with the project's existing Ruby / Rails / Minitest setup:

```sh
bin/rails test test/functional/calendar_timezone_test.rb
bin/rails test test/functional/appointments_controller_test.rb test/functional/datebooks_controller_test.rb
bin/rails test
```

The tests cover both admin and user roles, real test-database create/move/resize
round trips, repeated reads, unrelated edits, northern and southern DST,
half-hour and quarter-hour offsets, opposite sides of the date line, and the
offset-free FullCalendar feed. Controller coverage also verifies that the
normal JSON contract remains offset-bearing.

These Rails tests do not execute browser JavaScript. Before release, verify the
calendar in a real browser at desktop and mobile widths: load events, switch
month/week/day views, create an appointment, drag it, resize it, cancel both
confirmation dialogs, and confirm auto-refresh still works.

## Product rule still required

A practice timezone can itself contain a nonexistent local hour when clocks
move forward or a repeated local hour when clocks move backward. The upgrade
does not change Rails' existing parser behavior for those inputs. If practices
can schedule inside transition hours, the product should explicitly choose one
of these policies:

- reject nonexistent and ambiguous local times; or
- choose and communicate which occurrence is used.

This is distinct from the former viewer-timezone bug, which the UTC wall-clock
carrier removes.
