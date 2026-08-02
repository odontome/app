---
name: triage
description: Triage production errors from Bugsnag and fix the highest-priority one. Use when asked to triage errors, check Bugsnag, look at production errors, or fix the top error.
---

# Production error triage

Fetch open errors from Bugsnag (odontome-prod), rank them by business impact, fix the top one end to end, and open a PR for Raul to verify. Exactly one error per run — re-run for the next.

## Constants

- API base: `https://api.bugsnag.com`
- Project ID: `6043b9b3f908a5000e66364e` (odontome-prod)
- Error page for humans: `https://app.bugsnag.com/odontome-prod/odontome-prod/errors/<error_id>`
- Token: `BUGSNAG_DATA_ACCESS_TOKEN` in the gitignored `.env` at the repo root. This is a personal auth token for the Data Access API — `BUGSNAG_API_KEY` is the notifier key and will NOT work.

## Guardrails (absolute)

- **Read-only against Bugsnag.** GET requests only. Never comment on, snooze, or change the status of an error. Raul marks errors fixed after deploying.
- **Never merge the PR.** Only Raul merges.
- **No PII in written artifacts.** Events carry patient/user emails, names, and request params in `metaData`, `request`, and `user`. Use them to diagnose, but terminal summaries, commit messages, and PR bodies may only contain: error class, controller#action context, counts, timestamps, and in-project stack frames.
- **Never print the token.** Read it into a shell variable; don't echo it or put it in URLs.

## Step 1 — Fetch

Read the token (strip whitespace — a trailing space in `.env` has caused a real 401):

```bash
TOKEN=$(grep '^BUGSNAG_DATA_ACCESS_TOKEN=' <repo-root>/.env | cut -d= -f2- | tr -d '[:space:]')
```

List open errors (Raul's ignored/snoozed errors are excluded by this filter). Write responses to files in the scratchpad and parse from the file — zsh `echo` corrupts JSON backslashes:

```bash
curl -s -H "Authorization: token $TOKEN" -o errors.json \
  "https://api.bugsnag.com/projects/6043b9b3f908a5000e66364e/errors?filters%5Berror.status%5D%5B%5D%5Btype%5D=eq&filters%5Berror.status%5D%5B%5D%5Bvalue%5D=open&sort=last_seen&direction=desc&per_page=30"
```

Useful fields per error: `id`, `error_class`, `context`, `events`, `users`, `unhandled`, `severity`, `first_seen`, `last_seen`.

For each open error, fetch the latest full event (`/errors/:id/events/latest` does NOT exist — use the list with `per_page=1`):

```bash
curl -s -H "Authorization: token $TOKEN" -o event_<error_id>.json \
  "https://api.bugsnag.com/errors/<error_id>/events?per_page=1&full_reports=true"
```

Useful fields per event: `exceptions[0].message`, `exceptions[0].stacktrace` (filter `in_project: true`), `request`, `breadcrumbs`, `metaData`, `context`, `unhandled`.

**Stop conditions:** 401 → tell Raul to re-check `BUGSNAG_DATA_ACCESS_TOKEN` in `.env` (Bugsnag → Settings → My account → Personal auth tokens) and stop. Empty list → report "no open errors 🎉" and stop. 429 → wait for `Retry-After`, then retry once.

## Step 2 — Rank

Business criticality first. Judge each error by its context, stack trace, and event data — not by counts alone:

| Tier | What |
|---|---|
| 1 | Data integrity & security: data loss/corruption, auth bypass, PII exposure |
| 2 | Money: Stripe webhooks, billing, subscription lifecycle |
| 3 | Core clinical flows: appointments, patients, doctors |
| 4 | Everything else, including probable bot/crawler noise |

Tiebreakers within a tier, in order: unhandled beats handled, users affected, event volume, recent spike.

Judge **noise vs. signal** and match the fix to the diagnosis: bot traffic hitting a route with no HTML view deserves a graceful 404, not a new template; a CSRF failure might be a real user with a stale session or bots probing a form.

Present the full ranked table before touching code — one row per open error: error class, context, tier, events, users, one-line rationale, and which one is picked.

## Step 3 — Fix

- Create a worktree branching off `master`, branch named `fix/<short-slug>`.
- Root-cause using the stack trace plus real event data (params, breadcrumbs).
- Use superpowers:test-driven-development: write a failing test that reproduces the error first, then the minimal Rails-convention fix (model scopes, controller private methods, concerns — no service objects).
- Any user-facing copy goes into all three locales: `config/locales/{en,es,pt}.yml`. Never use `default:` on `I18n.t`.
- `bin/rails test` must pass in full before moving on.

## Step 4 — Review

Use superpowers:requesting-code-review to self-review the diff against the root cause. Apply improvements before pushing. Confirm no PII leaked into the diff, commit message, or planned PR body.

## Step 5 — Present

- Push the branch and open a PR with `gh pr create` (base `master`).
- The PR body is exactly two parts: one concise summary paragraph explaining root cause and fix, with the Bugsnag error page linked inline, then a `## Test plan` checklist with few-word items. Title is semantic (`fix(scope): …`).
- Report to Raul in chat: the PR link, the triage table with the remaining open errors so he sees the full picture, and the next-priority error. **Do not merge.**

## Edge cases

- **Not fixable from code** (third-party outage, needs a data backfill or console action): report findings and a recommendation instead of forcing a PR. Move to the next error only if Raul asks.
- **Already fixed on master** but still firing from the deployed release: report that, recommend deploy + marking fixed after; no duplicate fix.
