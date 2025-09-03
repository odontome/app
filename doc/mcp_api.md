# MCP (Model Control Panel) API Documentation

The MCP API provides CRUD operations for managing appointments and datebooks via JSON endpoints.

## Authentication

All endpoints require user authentication. The API uses session-based authentication inherited from the main application.

## Base URL

All MCP endpoints are prefixed with `/api/mcp/`

## Endpoints

### Appointments

#### List Appointments
```
GET /api/mcp/appointments
```
Returns: Array of appointments with doctor and patient information
Limit: 100 most recent appointments

#### Get Appointment
```
GET /api/mcp/appointments/:id
```
Returns: Single appointment with doctor and patient information

#### Create Appointment
```
POST /api/mcp/appointments
Content-Type: application/json

{
  "appointment": {
    "datebook_id": 1,
    "doctor_id": 1,
    "patient_id": 1,
    "starts_at": "2024-01-04T14:00:00Z",
    "ends_at": "2024-01-04T15:00:00Z",
    "notes": "Regular checkup",
    "status": "confirmed"
  }
}
```

#### Update Appointment
```
PATCH /api/mcp/appointments/:id
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