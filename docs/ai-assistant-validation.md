# AI assistant validation

## What changed

The main navigation now has an **AI** section at `/ai`, available to practice admins and regular users. The page shows short Claude and ChatGPT connection paths together using the existing Tabler card, form and grid components. Only practice admins can enable or disable AI for everyone. The previous `/practice/agent-settings` GET and PATCH URLs still work.

New AI changes use the connected user's ID in the activity log and display a localized **via AI** marker. User filters include both web and AI changes. Historical Agent entries retain their original labels and remain filterable.

## Before testing

1. Apply `bin/rails db:migrate` and restart the web and worker processes. The migration adds a nullable `activity_source` column to `versions`; an already-running process can cache the old schema. Use `bin/rails restart` for the local Puma server.
2. Use a disposable practice, with an admin and a regular user, an active trial/subscription, a doctor, and a calendar.
3. For hosted Claude or ChatGPT testing, use a reachable deployment of this code. A hosted client cannot connect to your computer's `localhost` URL. Confirm the connection's practice and timezone before any write.
4. Keep one pre-existing valid connection for the compatibility check. Opening the new screen or deploying the change must not revoke it.

## Acceptance checklist

### Admin and regular-user setup

- As an admin, open **AI** from the main navigation. AI no longer occupies a practice-settings card.
- With AI off, check the explanation and the visible **Practice access** card. Turning the switch on should save immediately. If agreement is required, the switch waits for that checkbox and saves when it is accepted.
- As an admin, turn AI off and cancel the confirmation. Access must remain on. Repeat and accept the confirmation: access should turn off and existing connections should be revoked.
- As a regular user, open the same section. When enabled, the Claude and ChatGPT connection rows should both appear. Claude shows the connection URL; ChatGPT does not. No examples or practice-wide switch should appear.
- As a regular user, try a forged PATCH to `/ai` and `/practice/agent-settings`: neither may change the practice setting or record AI consent.
- With AI off or subscription eligibility unmet, regular users should see a clear request to contact their practice administrator. Setup must not claim they can connect.
- Open `/practice/agent-settings` to verify existing bookmarks remain usable.

### Connect each app

Repeat with separate admin and regular-user accounts for Claude and ChatGPT:

1. Follow the relevant guide in **AI assistant**. ChatGPT plugin availability and Claude workspace-owner setup depend on that provider's workspace; they are independent of the user's Odonto.me role.
2. At the Odonto.me approval screen, verify the signed-in name, practice, client and return destination. Approve only the intended connection.
3. Ask: **“Use Odonto.me to show me today's appointments across all calendars.”** Compare every returned calendar with the app, including the practice-local dates and timezone.
4. On the same disposable practice, confirm the details of a new appointment, book it, then reschedule or cancel it. Verify the result in the app.
5. As an admin, filter the activity log by the connected user. Check the list and detail view show that user's name and **via AI**, and that any newly created patient is attributed to the same user.
6. Make an ordinary web edit as that user. It should retain the user's name and have no AI marker.

### Compatibility and revocation

- Use the pre-existing connection to read and update a disposable appointment. It should still work, and new changes should identify its original token owner.
- As an admin, disable AI with the Practice access switch. All existing connections must fail, including refresh attempts.
- Re-enable AI. Previously revoked connections must stay revoked; each person must reconnect.
- Inspect a historical Agent log entry and its filter. It must remain readable and must not be reassigned to a guessed user.
- In a disposable test only, move a token owner to another practice. Their old token must not retain access to the original practice.

### Screen and interaction checks

- Check English, Spanish and Portuguese at mobile, tablet and desktop widths in light and dark themes.
- Navigate the Claude copy control, provider guide links and Practice access switch with the keyboard and confirm visible focus.
- Use **Copy URL**: it should copy the full URL and announce success. If clipboard access is unavailable or denied, the field should receive focus, its text should be selected, and manual-copy instructions should appear.
- Confirm the translated instructions wrap without horizontal page scrolling. At 768px, verify the short AI / IA navigation label keeps the menu within the viewport.

## Automated verification

```sh
bin/rails test
AGENT_COVERAGE=1 bin/rails test test/functional/api/agent test/models/agent_oauth*_test.rb
node --test test/javascript/ai_test.js
```

This checkout uses Ruby 3.2.3. If the shell selects a different Ruby, run the Rails commands with `/Users/raulriera/.rbenv/versions/3.2.3/bin/ruby bin/rails`.

Verified results:

- RED checks demonstrated the missing dedicated section, old Agent attribution, missing audit source, access retained after a token owner changed practices, hidden provider paths, and the previous manual-save control.
- Focused final AI controller suite: **13 tests, 144 assertions; no failures, errors or skips**.
- Final full Rails suite: **652 tests, 4,036 assertions; no failures, errors or skips**.
- MCP/OAuth gate: **153 tests, 1,013 assertions; 515/515 lines covered (100%)**. This gate covers the agent controllers, MCP tool implementation and OAuth credential models.
- AI JavaScript: **7 tests passed**, covering clipboard behavior, immediate access saving, cancelled disconnection and required consent.
- Browser spot checks: English desktop at 1280px; Spanish tablet at 768px; Portuguese mobile at 390px in dark mode; Claude, ChatGPT and disabled states. The page had no horizontal overflow, buttons measured at least 44px high, and secondary text remained readable in dark mode.
- EN/ES/PT locale files parse with the same **24 AI keys**; `git diff --check` passed.
- Real HTTP calls to the local MCP server initialized successfully, created a synthetic patient and appointment, and cancelled the appointment. Persisted changes used the regular user's ID with `activity_source: ai`; the filtered audit list and detail screen showed the same attribution.
- Impeccable normal and layout detectors reported no findings.

## Remaining live validation

Hosted Claude and ChatGPT OAuth flows were not exercised against a deployed version of this change. Complete the provider checklist above before release. The MCP URL, discovery/OAuth endpoints, protocol negotiation, tool schemas and response shapes, PKCE, refresh rotation and token lifetimes are unchanged; the automated suite and local HTTP checks found no protocol regressions.
