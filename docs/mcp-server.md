# Odonto.me MCP Server

Odonto.me exposes an [MCP (Model Context Protocol)](https://modelcontextprotocol.io) server that lets AI assistants manage dental appointments through natural language. Connect it to apps like [Claude](https://claude.ai) to search patients, check schedules, and book or reschedule appointments — all without leaving the conversation.

## Server URL

```
https://my.odonto.me/api/agent/mcp
```

- **Transport:** HTTP POST for JSON-RPC
- **Protocol version:** `2025-11-25`

## Authentication

The server uses **OAuth 2.1 with PKCE**. Users sign in to Odonto.me and approve access for their own practice; no practice key is shared with ChatGPT.

### OAuth endpoints

| Endpoint | URL |
|---|---|
| Discovery | `https://my.odonto.me/.well-known/oauth-authorization-server` |
| Protected resource | `https://my.odonto.me/.well-known/oauth-protected-resource` |
| Authorize | `https://my.odonto.me/api/agent/oauth/authorize` |
| Token | `https://my.odonto.me/api/agent/oauth/token` |

### Setup

1. Go to **My Practice > AI Assistant** in odonto.me
2. Enable the AI assistant toggle
3. Sign in to Odonto.me when ChatGPT asks you to connect.
4. Review and approve access for your practice.

The connection is available only while the AI assistant is enabled and the practice has an active subscription or an unexpired trial. Past-due, cancelled, and expired subscriptions cannot authorize or use the MCP server. The approval screen identifies the signed-in user and practice, and the approval is bound to that exact Odonto.me session.

## Available tools

### list_datebooks

List all datebooks (appointment calendars) for the practice. Each datebook typically represents a clinic location.

**Parameters:** None

**Returns:** Array of `{ id, name }`

---

### list_doctors

List all active dentists and specialists. Returns their name, specialty, and ID needed for scheduling.

**Parameters:** None

**Returns:** Array of `{ id, uid, name, speciality }`

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

*One of `datebook_id` or `datebook_name` is required.

**Returns:** Array of `{ id, start, end, doctor_id, doctor_name, datebook_id, datebook_name, patient_id, patient_name, status }`

**Limits:** Maximum 90-day range, 500 results per query.

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

*One of `datebook_id` or `datebook_name` is required.
**One of `patient_id` or `patient_name` is required.

**Returns:** The created appointment object.

**Notes:**
- Times must fall within the datebook's working hours
- The server does not prevent double-booking — check availability first with `list_appointments`

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

**Returns:** The updated appointment object.

---

### search_patients

Search the patient directory by name or patient ID number (UID). Use this to look up a patient before booking.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `query` | string | yes | Patient name or UID to search for |

**Returns:** Array of `{ id, uid, firstname, lastname }`

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

- **`create_appointment`** is not idempotent — calling it twice creates duplicate appointments.
- **`update_appointment`** is destructive — it can cancel appointments.

## Security and privacy

- **Practice isolation:** All data is scoped to the authenticated practice. There is no cross-practice access.
- **No PII in responses:** The server only returns patient names and internal IDs. Email addresses, phone numbers, physical addresses, dates of birth, allergies, and insurance information are never exposed.
- **Rate limiting:** 120 requests/minute per authenticated practice or unauthenticated IP.
- **Request limits:** Bodies capped at 1 MB, date range queries limited to 90 days.
- **Audit trail:** All changes made through the AI assistant are logged and visible in the practice's audit trail.
- **Token management:** OAuth access tokens are SHA-256 hashed at rest, expire after one hour, and are revoked when AI access is disabled or the practice closes.

## Testing

Run the focused agent suite with its enforced 100% line-coverage gate:

```sh
AGENT_COVERAGE=1 bin/rails test test/functional/api/agent test/models/agent_oauth_credential_test.rb
```

The gate covers the agent controllers, MCP tool implementation, and OAuth credential models. The full application suite remains `bin/rails test`.
