# Odonto.me MCP Server

Odonto.me exposes an [MCP (Model Context Protocol)](https://modelcontextprotocol.io) server that lets AI assistants manage dental appointments through natural language. Connect it to apps like [Claude](https://claude.ai) to search patients, check schedules, and book or reschedule appointments — all without leaving the conversation.

## Server URL

```
https://my.odonto.me/api/agent/mcp
```

- **Transport:** Streamable HTTP (POST for JSON-RPC, GET with `Accept: text/event-stream` for SSE)
- **Protocol version:** `2025-11-25`

## Authentication

The server uses **OAuth 2.0 with PKCE**. Most MCP clients (Claude Desktop, Claude.ai) handle this automatically.

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
3. Generate a secret key — this is your `client_id` and `client_secret`
4. Copy the connection URL into your AI app's MCP connector settings

The secret key is shown once. If lost, generate a new one (the old key is immediately revoked).

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

**Returns:** Array of `{ id, start, end, doctor_id, doctor_name, datebook_id, datebook_name, patient_id, patient_name, status, notes }`

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
| `notes` | string | no | Reason for visit (max 255 characters) |

*One of `datebook_id` or `datebook_name` is required.
**One of `patient_id` or `patient_name` is required.

**Returns:** The created appointment object.

**Notes:**
- If `ends_at` is omitted, it defaults to 60 minutes after `starts_at`
- Times must fall within the datebook's working hours
- The server does not prevent double-booking — check availability first with `list_appointments`

---

### update_appointment

Modify an existing appointment — reschedule, reassign to a different doctor, update notes, cancel, or confirm.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `appointment_id` | integer | yes | Appointment ID to update |
| `doctor_id` | integer | no | Reassign to a different doctor |
| `starts_at` | string | no | New start time — ISO 8601 |
| `ends_at` | string | no | New end time — ISO 8601 |
| `notes` | string | no | Updated reason for visit |
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

- 9:00 AM — Maria Santos with Dr. Garcia — Routine cleaning
- 10:30 AM — Carlos Lopez with Dr. Garcia — Crown prep
- 2:00 PM — Ana Martinez with Dr. Rodriguez — Orthodontic check-up

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
- **Rate limiting:** 120 requests/minute per practice, 60 requests/minute per IP.
- **Request limits:** Bodies capped at 1 MB, date range queries limited to 90 days.
- **Audit trail:** All changes made through the AI assistant are logged and visible in the practice's audit trail.
- **Key management:** API keys are SHA-256 hashed at rest. Keys can be revoked and regenerated at any time from the practice settings.
