# Model Context Protocol (MCP) Server Documentation

The Odontome MCP Server implements the Model Context Protocol standard for AI model integration, providing secure access to dental practice data through JSON-RPC 2.0 messaging.

## Overview

The MCP Server enables AI models and tools to interact with dental practice management data through standardized JSON-RPC requests. It provides secure, authenticated access to appointments and datebooks while maintaining proper practice scoping and data isolation.

## Authentication

All endpoints require user authentication via session-based authentication inherited from the main application. Users can only access data from their associated dental practice.

## Base URL

All MCP endpoints are prefixed with `/api/mcp/`

## Endpoints

### Capabilities Discovery
```
GET /api/mcp/capabilities
```

Returns the server capabilities, available tools, and resource definitions following MCP standard.

**Response:**
```json
{
  "capabilities": {
    "tools": [...],
    "resources": [...]
  },
  "serverInfo": {
    "name": "Odontome MCP Server",
    "version": "1.0.0",
    "description": "Model Context Protocol server for Odontome dental practice management"
  },
  "protocolVersion": "2024-11-05"
}
```

### Request Handler
```
POST /api/mcp
Content-Type: application/json
```

Handles JSON-RPC 2.0 requests with the following format:

**Request Format:**
```json
{
  "jsonrpc": "2.0",
  "method": "method_name",
  "params": { ... },
  "id": 1
}
```

**Response Format:**
```json
{
  "jsonrpc": "2.0",
  "result": { ... },
  "id": 1
}
```

**Error Response Format:**
```json
{
  "jsonrpc": "2.0",
  "error": {
    "code": -32601,
    "message": "Method not found"
  },
  "id": 1
}
```

## Available Methods

### Appointments

#### appointments/list
List appointments with doctor and patient information.

**Parameters:**
- `limit` (integer, optional): Maximum number of appointments to return (default 100)
- `doctor_id` (integer, optional): Filter by doctor ID
- `patient_id` (integer, optional): Filter by patient ID  
- `start_date` (string, optional): Filter appointments after this date (ISO 8601)
- `end_date` (string, optional): Filter appointments before this date (ISO 8601)

**Example:**
```json
{
  "jsonrpc": "2.0",
  "method": "appointments/list",
  "params": {
    "limit": 50,
    "doctor_id": 1,
    "start_date": "2024-01-01T00:00:00Z"
  },
  "id": 1
}
```

#### appointments/get
Get specific appointment by ID.

**Parameters:**
- `id` (integer, required): Appointment ID

**Example:**
```json
{
  "jsonrpc": "2.0",
  "method": "appointments/get",
  "params": { "id": 123 },
  "id": 2
}
```

#### appointments/create
Create new appointment.

**Parameters:**
- `datebook_id` (integer, required): Datebook ID
- `doctor_id` (integer, optional): Doctor ID
- `patient_id` (integer, optional): Patient ID
- `starts_at` (string, required): Appointment start time (ISO 8601)
- `ends_at` (string, optional): Appointment end time (ISO 8601)
- `notes` (string, optional): Appointment notes
- `status` (string, optional): Appointment status

**Example:**
```json
{
  "jsonrpc": "2.0",
  "method": "appointments/create",
  "params": {
    "datebook_id": 1,
    "doctor_id": 1,
    "patient_id": 1,
    "starts_at": "2024-01-04T14:00:00Z",
    "ends_at": "2024-01-04T15:00:00Z",
    "notes": "Regular checkup",
    "status": "confirmed"
  },
  "id": 3
}
```

#### appointments/update
Update existing appointment.

**Parameters:**
- `id` (integer, required): Appointment ID
- Other parameters same as create (all optional except id)

**Example:**
```json
{
  "jsonrpc": "2.0",
  "method": "appointments/update",
  "params": {
    "id": 123,
    "notes": "Updated notes",
    "status": "confirmed"
  },
  "id": 4
}
```

#### appointments/delete
Delete appointment.

**Parameters:**
- `id` (integer, required): Appointment ID

**Example:**
```json
{
  "jsonrpc": "2.0",
  "method": "appointments/delete",
  "params": { "id": 123 },
  "id": 5
}
```

### Datebooks

#### datebooks/list
List datebooks with optional appointment information.

**Parameters:**
- `include_appointments` (boolean, optional): Include appointments in response (default true)

**Example:**
```json
{
  "jsonrpc": "2.0",
  "method": "datebooks/list",
  "params": { "include_appointments": true },
  "id": 6
}
```

#### datebooks/get
Get specific datebook by ID.

**Parameters:**
- `id` (integer, required): Datebook ID
- `include_appointments` (boolean, optional): Include appointments in response (default true)

**Example:**
```json
{
  "jsonrpc": "2.0",
  "method": "datebooks/get",
  "params": { 
    "id": 1,
    "include_appointments": true 
  },
  "id": 7
}
```

#### datebooks/create
Create new datebook.

**Parameters:**
- `name` (string, required): Datebook name
- `starts_at` (string, optional): Start time (HH:MM format)
- `ends_at` (string, optional): End time (HH:MM format)

**Example:**
```json
{
  "jsonrpc": "2.0",
  "method": "datebooks/create",
  "params": {
    "name": "Dr. Smith Schedule",
    "starts_at": "08:00",
    "ends_at": "17:00"
  },
  "id": 8
}
```

#### datebooks/update
Update existing datebook.

**Parameters:**
- `id` (integer, required): Datebook ID
- `name` (string, optional): Datebook name
- `starts_at` (string, optional): Start time (HH:MM format)
- `ends_at` (string, optional): End time (HH:MM format)

**Example:**
```json
{
  "jsonrpc": "2.0",
  "method": "datebooks/update",
  "params": {
    "id": 1,
    "name": "Updated Schedule"
  },
  "id": 9
}
```

#### datebooks/delete
Delete datebook (only if no appointments exist).

**Parameters:**
- `id` (integer, required): Datebook ID

**Example:**
```json
{
  "jsonrpc": "2.0",
  "method": "datebooks/delete",
  "params": { "id": 1 },
  "id": 10
}
```

## Error Codes

The MCP server uses standard JSON-RPC 2.0 error codes:

- `-32700`: Parse error - Invalid JSON was received
- `-32600`: Invalid Request - The JSON sent is not a valid Request object
- `-32601`: Method not found - The method does not exist / is not available
- `-32603`: Internal error - Internal JSON-RPC error

## Security Features

- **Authentication Required**: All endpoints require valid user sessions
- **Practice Scoping**: Data is automatically scoped to the authenticated user's practice
- **Ownership Validation**: Additional checks ensure resources belong to the user's practice
- **Parameter Filtering**: Only allowed parameters are processed to prevent injection attacks
- **CSRF Protection**: Appropriately disabled for API endpoints while maintaining session-based auth

## Usage Examples

### Using curl

```bash
# Get server capabilities
curl -X GET /api/mcp/capabilities

# List appointments
curl -X POST /api/mcp \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "appointments/list",
    "params": {"limit": 10},
    "id": 1
  }'

# Create appointment
curl -X POST /api/mcp \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "appointments/create",
    "params": {
      "datebook_id": 1,
      "doctor_id": 1,
      "patient_id": 1,
      "starts_at": "2024-01-04T14:00:00Z",
      "notes": "Regular checkup"
    },
    "id": 2
  }'
```

### AI Model Integration

AI models can use the MCP server to:

1. **Query appointment schedules** - Get upcoming appointments and availability
2. **Access patient appointment history** - Review past appointments for context
3. **Create appointments programmatically** - Schedule new appointments based on AI recommendations
4. **Retrieve datebook configurations** - Understand practice scheduling parameters
5. **Manage appointment data** - Update notes, status, and other appointment details

## Resource URIs

The MCP server exposes the following resource URIs for AI model reference:

- `odontome://appointments` - Dental practice appointments with doctor and patient information
- `odontome://datebooks` - Appointment scheduling datebooks for dental practice

## Implementation Notes

- All date/time parameters should be provided in ISO 8601 format
- The server automatically handles time zone conversion based on practice settings
- Appointment validation ensures scheduling conflicts are prevented
- Datebooks can only be deleted if they have no associated appointments
- All responses include related doctor and patient information when applicable
- Maximum of 100 appointments can be returned in a single list request
Content-Type: application/json

{
  "appointment": {
    "notes": "Updated notes",
    "status": "confirmed"
  }
}
```

#### Delete Appointment
```
DELETE /api/mcp/appointments/:id
```

### Datebooks

#### List Datebooks
```
GET /api/mcp/datebooks
```
Returns: Array of datebooks with their appointments

#### Get Datebook
```
GET /api/mcp/datebooks/:id
```
Returns: Single datebook with appointments

#### Create Datebook
```
POST /api/mcp/datebooks
Content-Type: application/json

{
  "datebook": {
    "name": "Main Office",
    "starts_at": 8,
    "ends_at": 18
  }
}
```

#### Update Datebook
```
PATCH /api/mcp/datebooks/:id
Content-Type: application/json

{
  "datebook": {
    "name": "Updated Office Name"
  }
}
```

#### Delete Datebook
```
DELETE /api/mcp/datebooks/:id
```
Note: Only datebooks without appointments can be deleted.

## Security Features

- **Practice Scoping**: All data is automatically scoped to the authenticated user's practice
- **Input Validation**: Strong parameters prevent mass assignment vulnerabilities
- **Authentication**: All endpoints require valid user authentication
- **Error Handling**: Proper HTTP status codes and JSON error responses

## Response Formats

### Success Response
```json
{
  "id": 1,
  "name": "Main Office",
  "starts_at": 8,
  "ends_at": 18,
  "practice_id": 1,
  "created_at": "2024-01-01T00:00:00Z",
  "updated_at": "2024-01-01T00:00:00Z"
}
```

### Error Response
```json
{
  "errors": ["Name can't be blank", "Starts at must be greater than 0"]
}
```

### Not Found Response
```json
{
  "error": "Record not found"
}
```

## HTTP Status Codes

- `200 OK` - Successful GET, PATCH requests
- `201 Created` - Successful POST requests
- `204 No Content` - Successful DELETE requests
- `401 Unauthorized` - Authentication required
- `403 Forbidden` - No practice associated with user
- `404 Not Found` - Resource not found or not accessible
- `422 Unprocessable Entity` - Validation errors