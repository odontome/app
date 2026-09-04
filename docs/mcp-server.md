# Odonto.me MCP Server

Odonto.me exposes an [MCP (Model Context Protocol)](https://modelcontextprotocol.io) server that lets AI assistants manage dental appointments through natural language. Connect it to apps like [Claude](https://claude.ai) to search patients, check schedules, and book or reschedule appointments — all without leaving the conversation.

## Server URL

```
https://my.odonto.me/api/agent/mcp
```

- **Transport:** HTTP POST for JSON-RPC
- **Protocol version:** Negotiated from the client's `initialize` request
- **Icon:** `initialize` includes the public [Odonto.me app icon](https://my.odonto.me/apple-touch-icon-precomposed.png) as a 256 × 256 PNG. Clients may show it when displaying the connection.

## Authentication

The server uses **OAuth 2.1 with PKCE** and public [Client ID Metadata Documents](https://datatracker.ietf.org/doc/draft-ietf-oauth-client-id-metadata-document/). Users sign in to Odonto.me and approve access for their own practice; no practice key is shared with the AI client.

This is provider-neutral: ChatGPT, Claude Code, hosted clients, and future clients can connect when they publish a valid HTTPS metadata document. The document must declare a public `none` token authentication option and an exact HTTPS callback, or an HTTP callback on `localhost`, `127.0.0.1`, or `[::1]`. A loopback callback may select a different numeric port; every other byte must match. The consent screen shows both the metadata host and callback host before access is granted.

### OAuth endpoints

| Endpoint | URL |
|---|---|
| Discovery | `https://my.odonto.me/.well-known/oauth-authorization-server` |
| Protected resource | `https://my.odonto.me/.well-known/oauth-protected-resource/api/agent/mcp` |
| Authorize | `https://my.odonto.me/api/agent/oauth/authorize` |
| Token | `https://my.odonto.me/api/agent/oauth/token` |

### Setup

1. Open **AI assistant** in the main navigation (`/ai`). Admins and regular users can both open this section. The previous `/practice/agent-settings` URL remains available.
2. A practice administrator enables AI for the team and accepts the AI data-processing terms. Only admins can save this practice-wide setting, including through the legacy settings URL.
3. Follow the guide for your AI app. ChatGPT uses plugin installation; Claude uses a remote connector with the existing MCP URL. Availability and workspace-owner setup in the AI app are separate from the user's role in Odonto.me.
4. Each team member signs in to Odonto.me with their own account when their AI app asks them to connect, checks their name and practice, and approves access.
5. Start a conversation and ask Odonto.me for today's schedule across all calendars.

The setup screen shows actionable guidance when AI is disabled or eligibility requirements are unmet. It does not equate practice-wide enablement with a personally connected AI app. Current provider instructions are linked from the screen: [ChatGPT plugins](https://learn.chatgpt.com/docs/plugins) and [Claude connectors](https://support.claude.com/en/articles/11175166-get-started-with-custom-connectors-using-remote-mcp).

The connection is available only while the AI assistant is enabled and the practice has an active subscription or an unexpired trial. Past-due, cancelled, and expired subscriptions cannot authorize or use the MCP server. The approval screen identifies the signed-in user and practice, and the approval is bound to that exact Odonto.me session.

Authorization requires S256 PKCE and binds the code to the exact client ID, callback, and canonical protected-resource URL. Access tokens expire after one hour. Clients that declare the `refresh_token` grant receive a rotating refresh token with a 90-day lifetime. Reusing a spent refresh token or redeemed authorization code revokes that connection's full token family. Disabling AI access or closing a practice revokes all credentials, including refresh credentials.

Client documents are fetched without ambient proxies, only after every resolved address passes public-address checks, and with a pinned vetted address for TLS and HTTP. Redirect responses are rejected, response bodies are streamed with a 64 KB maximum, and DNS, connection, TLS, and body processing share a five-second deadline. Invalid responses and errors are never cached; successful responses honor restrictive cache directives and are capped at one hour.

Authorization requests are limited to 30 per minute per remote address. Token and approval requests share a 60-per-minute limit.

Browser-based clients must send no `Origin`, use the server's own origin, or use one of the built-in ChatGPT/Claude origins. Extra trusted browser origins can be provided as a comma-separated `MCP_ALLOWED_ORIGINS` environment variable. Server-to-server clients normally send no `Origin` and are unaffected.

## Available tools

### list_datebooks

List all datebooks (appointment calendars) for the practice. Each datebook typically represents a clinic location.

**Parameters:** None

**Returns:** Structured content `{ datebooks: [{ id, name, timezone, working_hours: { start, end } }] }`.

`timezone` is the practice's IANA timezone (for example, `America/New_York`). `working_hours.start` and `working_hours.end` are local `HH:MM` opening and closing times on each day. Read these values before proposing a booking or reschedule; do not infer opening hours from an empty appointment list. Use the timezone offset applicable to the appointment date, including daylight-saving changes. The entire appointment must fit inside the same day's working hours; ending exactly at closing is allowed, but ending even part of an hour later or on another day is rejected.

The Rails calendar also displays practice-local time without an extra timezone label. FullCalendar 6.1.18 runs in UTC as a neutral wall-clock carrier, so a staff member's device timezone cannot shift the practice schedule. Calendar clicks, moves, resizes, and date-range queries send displayed wall-clock fields rather than browser-local epochs. See [calendar timezone regression coverage](calendar-timezone-testing.md). MCP appointment timestamps retain their explicit offsets. Existing calendar Unix-timestamp inputs remain accepted.

---

### list_doctors

List all active dentists and specialists. Returns their name, specialty, and ID needed for scheduling.

**Parameters:** None

**Returns:** Structured content `{ doctors: [{ id, uid, name, speciality }] }`

---

### list_appointments

Query the schedule for a date range. Use this to check availability, see who is coming in today, or review upcoming appointments.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `datebook_id` | integer | no* | Datebook ID |
| `datebook_name` | string | no* | Datebook name (alternative to datebook_id) |
| `start` | string | yes | Range start — ISO 8601 in the practice's timezone |
| `end` | string | yes | Range end — ISO 8601 in the practice's timezone |
| `doctor_id` | integer | no | Filter by a specific doctor |

*One of `datebook_id` or `datebook_name` is required. The input schema expresses this with `anyOf`, preserving both lookup forms. If the calendar is unknown, call `list_datebooks` first. For a practice-wide schedule, query each returned calendar separately. Missing or blank selectors return an MCP tool error directing the caller to `list_datebooks`; a failed query must not be reported as an empty schedule.

**Returns:** Structured content `{ appointments: [{ id, start, end, doctor_id, doctor_name, datebook_id, datebook_name, patient_id, patient_name, status }] }`

**Limits:** Maximum 90-day range, 500 results per query.

Use `start` and `end` for schedule queries, not the `starts_at` and `ends_at` fields used by appointment writes. Missing, blank, or unparseable dates return an actionable MCP tool error (`isError: true`) rather than an HTTP 500 or an empty appointment list. Existing ISO 8601 and Unix timestamp inputs remain supported.

---

### create_appointment

Book a new patient appointment. You can reference an existing patient by ID or provide a name to create a new patient record automatically.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `datebook_id` | integer | no* | Datebook ID |
| `datebook_name` | string | no* | Datebook name (alternative to datebook_id) |
| `doctor_id` | integer | yes | Doctor who will see the patient |
| `patient_id` | integer | no** | Existing patient ID (use `search_patients` to find) |
| `patient_name` | string | no** | Full name for a new patient |
| `starts_at` | string | yes | Start time — ISO 8601 in the practice's timezone |
| `ends_at` | string | yes | End time — ISO 8601 in the practice's timezone |

*One of `datebook_id` or `datebook_name` is required, expressed with `anyOf` in the input schema. Missing or blank selectors return an MCP tool error before creating a patient or appointment.
**One of `patient_id` or `patient_name` is required.

**Returns:** Structured content `{ appointment: { id, start, end, doctor_id, doctor_name, datebook_id, datebook_name, patient_id, patient_name, status } }`.

**Notes:**
- Times must fall within the datebook's working hours.
- Use `list_appointments` with the selected doctor and exact time range before booking. The server rejects an agent request that overlaps a non-cancelled appointment for that doctor in the selected datebook.
- Confirm the exact patient, doctor, datebook, date, and time with the user before booking. Search for an existing patient before supplying `patient_name`, because that value creates a new record.

---

### update_appointment

Modify an existing appointment — reschedule, reassign to a different doctor, cancel, or confirm.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `appointment_id` | integer | yes | Appointment ID to update |
| `doctor_id` | integer | no | Reassign to a different doctor |
| `starts_at` | string | no | New start time — ISO 8601 |
| `ends_at` | string | no | New end time — ISO 8601 |
| `status` | string | no | `confirmed` or `cancelled` |

**Returns:** Structured content `{ appointment: { id, start, end, doctor_id, doctor_name, datebook_id, datebook_name, patient_id, patient_name, status } }`.

**Notes:** Confirm the exact change with the user before calling this tool. Before rescheduling or reassigning, check the selected doctor's availability with `list_appointments`; the server rejects an overlap with a non-cancelled appointment for that doctor in the datebook.

---

### search_patients

Search the patient directory by name or patient ID number (UID). Use this to look up a patient before booking.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `query` | string | yes | Patient name or UID to search for |

**Returns:** Structured content `{ patients: [{ id, uid, firstname, lastname }] }`

**Limits:** Maximum 25 results.

## Usage examples

### Check today's schedule

> **"What appointments do I have today?"**

The assistant calls `list_datebooks` to find available calendars, then `list_appointments` with today's date range. It returns a formatted list like:

- 9:00 AM — Maria Santos with Dr. Garcia
- 10:30 AM — Carlos Lopez with Dr. Garcia
- 2:00 PM — Ana Martinez with Dr. Rodriguez

### Book a new appointment

> **"Book a cleaning for Juan Perez with Dr. Garcia next Tuesday at 3 PM"**

The assistant calls `search_patients` to find Juan, `list_doctors` to confirm Dr. Garcia, `list_appointments` to verify the slot is open, then `create_appointment` to book it. Returns a confirmation with the appointment details.

### Reschedule and cancel

> **"Move my 2 PM appointment tomorrow to 4 PM, and cancel the 10 AM one"**

The assistant calls `list_appointments` to find tomorrow's schedule, then `update_appointment` twice — once to change the start/end time, and once to set status to `cancelled`.

## Safety annotations

All tools include [MCP safety annotations](https://modelcontextprotocol.io/specification/2025-03-26/server/tools#annotations) to help AI clients make informed decisions:

| Tool | Read-only | Destructive | Idempotent | Open-world |
|---|---|---|---|---|
| `list_datebooks` | yes | no | yes | no |
| `list_doctors` | yes | no | yes | no |
| `list_appointments` | yes | no | yes | no |
| `create_appointment` | no | no | no | no |
| `update_appointment` | no | yes | yes | no |
| `search_patients` | yes | no | yes | no |

- **`create_appointment`** is not idempotent — calling it twice may create duplicate appointments when the calls request different time slots.
- **`update_appointment`** is destructive — it can cancel appointments.

## Security and privacy

- **Practice isolation:** All data is scoped to the authenticated practice. There is no cross-practice access.
- **No PII in responses:** The server only returns patient names and internal IDs. Email addresses, phone numbers, physical addresses, dates of birth, allergies, and insurance information are never exposed.
- **Scheduling workflow:** The server instructs clients to resolve ambiguous scheduling details, search before creating a patient record, check availability before a booking or move, and obtain explicit confirmation before every schedule change. Confirmation instructions guide clients; the server enforces working hours and appointment-overlap checks.
- **Rate limiting:** 120 requests/minute per authenticated practice or unauthenticated IP.
- **Request limits:** Bodies capped at 1 MB, date range queries limited to 90 days.
- **Audit trail:** New changes made through the AI assistant use the OAuth access token owner's user ID as PaperTrail `whodunnit`, with `activity_source: "ai"`. The audit list and details show the user's name plus a localized “via AI” marker. Filtering by a user includes both their web and AI activity. Historical `agent:<label>` entries and filters remain readable; they are not reassigned to a guessed user. The legacy `agent_label` database field is retained, but no longer appears in settings or labels new changes.
- **User identity:** Both admins and regular users can authorize their own connections. Each MCP request verifies that the token's owner still belongs to the token's practice. No user identity or new metadata is added to MCP tool responses.
- **Request isolation:** AI audit metadata is scoped to the request and restored afterward, including error paths; ordinary web activity is not tagged as AI.
- **Token management:** OAuth access and refresh tokens are SHA-256 hashed at rest. Access tokens expire after one hour; refresh tokens rotate and expire after 90 days. Credentials are revoked when AI access is disabled or the practice closes.

## Testing

Run the focused agent suite with its enforced 100% line-coverage gate:

```sh
AGENT_COVERAGE=1 bin/rails test test/functional/api/agent test/models/agent_oauth*_test.rb
```

The gate covers the agent controllers, MCP tool implementation, and OAuth credential models. The full application suite remains `bin/rails test`.

### AI section compatibility and deployment

Apply `bin/rails db:migrate`, then restart all web and worker processes before serving requests with the updated app. Already-running processes can cache the old PaperTrail schema. The migration adds one nullable `versions.activity_source` column; it preserves existing audit rows and OAuth credentials.

The MCP URL, discovery and OAuth endpoints, tool names and argument schemas, response shapes, protocol negotiation, token lifetimes, PKCE and refresh rotation are unchanged. Existing valid tokens still work and now identify their owner in new audit entries. Turning AI off continues to revoke all practice credentials; turning it back on does not revive old connections.

See [AI assistant validation](ai-assistant-validation.md) for the automated checks and manual acceptance checklist.
