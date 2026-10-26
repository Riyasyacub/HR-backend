# API contract

Base path: `/api/v1`. Requests and responses are JSON.

## Conventions

- Single resources are returned under `data`.
- Lists are returned under `data` with `meta: { page, per_page, total }`.
- Errors use the envelope below and an appropriate HTTP status:

```json
{
  "error": {
    "code": "invalid_credentials",
    "message": "Invalid email or password",
    "details": []
  }
}
```

- Access tokens are short-lived JWTs sent as `Authorization: Bearer <token>`.
- Refresh tokens are opaque values stored in an `HttpOnly` cookie and never returned in a
  response body.
- The refresh cookie is scoped to `/api/v1/auth`; other API routes do not receive it.

## User object

```json
{
  "id": 1,
  "name": "HR Admin",
  "email": "hr@demo.test",
  "role": "HR",
  "country": "India",
  "employee_id": 1
}
```

`role` is `HR` or `standard_employee`. Managers are derived from the reporting hierarchy, not stored
as a role. `employee_id` is the linked employee record id, or `null` when the user has no employee
record.

## S01 authentication

### POST `/api/v1/auth/sign_in`

Public. Verifies credentials and starts a server-side session.

Request:

```json
{
  "email": "hr@demo.test",
  "password": "Demo@1234"
}
```

Success: `200 OK`

```json
{
  "data": {
    "access_token": "<jwt>",
    "token_type": "Bearer",
    "expires_in": 900,
    "user": {
      "id": 1,
      "name": "HR Admin",
      "email": "hr@demo.test",
      "role": "HR",
      "country": "India",
      "employee_id": null
    }
  }
}
```

Also sets:

```text
Set-Cookie: refresh_token=<opaque>; Path=/api/v1/auth; Expires=<...>; HttpOnly; SameSite=Lax
```

`Secure` is added in production. `expires_in` is in seconds.

Failure: `401 Unauthorized` with code `invalid_credentials`. The same message is returned for an
unknown email, a wrong password, and an inactive account, and no session or cookie is created.

### POST `/api/v1/auth/refresh`

Public, but requires the refresh cookie. Rotates the refresh token and issues a new access token.
A missing, invalid, revoked, or inactive-expired refresh token returns `401 Unauthorized` with code
`invalid_refresh_token`.

Success is the same `data` shape as sign-in, with a new `refresh_token` cookie.

### DELETE `/api/v1/auth/sign_out`

Requires the refresh cookie. Revokes the current server-side session and clears the cookie.
Returns `204 No Content`; repeating it is safe.

### GET `/api/v1/me`

Requires a valid access token.

Success: `200 OK`

```json
{
  "data": {
    "user": {
      "id": 1,
      "name": "HR Admin",
      "email": "hr@demo.test",
      "role": "HR",
      "country": "India",
      "employee_id": null
    }
  }
}
```

Failure: `401 Unauthorized` with code `invalid_token` when the access token is missing, expired,
invalid, revoked, belongs to an inactive account, or no longer matches the user's token version.
Each authenticated request also extends the session's inactivity window.

## S02 HR configuration

Configuration endpoints require an HR access token. Employees and managers receive `403 forbidden`.
Countries are read-only; departments support create, rename, and deactivate; leave types expose
audited entitlement updates.

### GET `/api/v1/settings/countries`

Returns the fixed country reference data. Countries and their currencies are read-only; there are no
create, update, or delete endpoints.

Success: `200 OK`

```json
{
  "data": [
    { "name": "India", "currency": "INR" },
    { "name": "USA", "currency": "USD" },
    { "name": "Canada", "currency": "CAD" }
  ],
  "meta": { "page": 1, "per_page": 3, "total": 3 }
}
```

Failure: `401 Unauthorized` with code `invalid_token` without a valid access token, or
`403 Forbidden` with code `forbidden` for a non-HR user.

### GET `/api/v1/settings/departments`

HR only. Returns all departments ordered by name, including deactivated departments.

Success: `200 OK`

```json
{
  "data": [
    { "id": 1, "name": "Engineering", "code": "ENG", "active": true }
  ],
  "meta": { "page": 1, "per_page": 1, "total": 1 }
}
```

### POST `/api/v1/settings/departments`

HR only. Creates a department. Names and codes are case-insensitively unique; names are trimmed and
codes are uppercased.

Request:

```json
{
  "department": {
    "name": "Engineering",
    "code": "ENG"
  }
}
```

Success: `201 Created`

```json
{
  "data": { "id": 1, "name": "Engineering", "code": "ENG", "active": true }
}
```

Failure: `422 Unprocessable Content` with code `validation_failed` and field messages in `details`.

### PATCH `/api/v1/settings/departments/:id`

HR only. Renames an existing department. The code is immutable after creation.

Request:

```json
{
  "department": {
    "name": "Product Engineering"
  }
}
```

Success: `200 OK` with the updated department under `data`.

Failure: `422 Unprocessable Content` with code `validation_failed` for a duplicate or blank name.

### PATCH `/api/v1/settings/departments/:id/deactivate`

HR only. Marks the department inactive without deleting it. The department remains available to
existing records.

Success: `200 OK` with `active: false` under `data`.

There is deliberately no `DELETE /api/v1/settings/departments/:id` route.

### GET `/api/v1/settings/leave_types`

HR only. Returns the four fixed leave types in display order. `balance_tracked` is `false` for
Unpaid, which has no entitlement. Defaults seeded for the demo are Earned 6, Sick 6, Casual 6, and
Unpaid `null`.

Success: `200 OK`

```json
{
  "data": [
    { "id": 1, "name": "Earned", "default_entitlement": 6, "balance_tracked": true },
    { "id": 2, "name": "Sick", "default_entitlement": 6, "balance_tracked": true },
    { "id": 3, "name": "Casual", "default_entitlement": 6, "balance_tracked": true },
    { "id": 4, "name": "Unpaid", "default_entitlement": null, "balance_tracked": false }
  ],
  "meta": { "page": 1, "per_page": 4, "total": 4 }
}
```

### PATCH `/api/v1/settings/leave_types/:id`

HR only. Updates the default annual entitlement for a balanced leave type. The name and balance
tracking flag are immutable. Unpaid leave cannot receive an entitlement.

Request:

```json
{
  "leave_type": {
    "default_entitlement": 18
  }
}
```

Success: `200 OK` with the updated leave type under `data`.

Failure: `422 Unprocessable Content` with code `validation_failed` for a negative/non-integer value
or for Unpaid.

Each changed entitlement writes an `audit_entries` row with the HR actor and
`{ "from": <old>, "to": <new> }`. Unchanged values write no audit entry.

## S03 Employee records

Employee list and create access is HR only. Profile access is available to HR and to the linked
employee. The list omits compensation and bank details; compensation is returned by the create
response. Monetary values are decimal strings with two places.

### GET `/api/v1/employees`

HR only. Returns employees ordered by `employee_id`. Results are offset-paginated with `page`
(default 1) and `per_page` (default 25, maximum 100).

Success: `200 OK`

```json
{
  "data": [
    {
      "id": 1,
      "employee_id": "EMP101",
      "first_name": "Ravi",
      "last_name": "Kumar",
      "work_email": "ravi@demo.test",
      "country": "India",
      "currency": "INR",
      "job_title": "Software Engineer",
      "start_date": "2026-01-01",
      "status": "active",
      "department": { "id": 1, "name": "Engineering" }
    }
  ],
  "meta": { "page": 1, "per_page": 25, "total": 1 }
}
```

Failure: `401 Unauthorized` with code `invalid_token` without a valid access token, or
`403 Forbidden` with code `forbidden` for a non-HR user.

### GET `/api/v1/employees/:id`

HR can view any employee. A standard employee can view only the record linked to their own user;
another employee's URL returns `403 Forbidden`. The response includes bank details and the latest
compensation with its components.

Success: `200 OK`

```json
{
  "data": {
    "id": 1,
    "employee_id": "EMP101",
    "first_name": "Ravi",
    "last_name": "Kumar",
    "work_email": "ravi@demo.test",
    "country": "India",
    "currency": "INR",
    "job_title": "Software Engineer",
    "start_date": "2026-01-01",
    "status": "active",
    "department": { "id": 1, "name": "Engineering" },
    "bank": {
      "bank_name": "HDFC Bank",
      "ifsc": "HDFC0001234",
      "account_number": "123456789012"
    },
    "compensation": {
      "id": 1,
      "effective_date": "2026-01-01",
      "annual_ctc": "1200000.00",
      "currency": "INR",
      "components": [
        { "id": 1, "name": "Basic", "annual_amount": "1000000.00" },
        { "id": 2, "name": "Allowance", "annual_amount": "200000.00" }
      ]
    }
  }
}
```

Failure: `401 Unauthorized` with code `invalid_token`, `403 Forbidden` with code `forbidden`, or
`404 Not Found` for an unknown employee id.

### POST `/api/v1/employees`

HR only. Creates an employee, an initial compensation row, and its components in one transaction.
Currency is derived from the employee's country. Annual CTC is not accepted as an input; it is
calculated from the component amounts and returned as a decimal string.

Request:

```json
{
  "employee": {
    "employee_id": "EMP101",
    "first_name": "Ravi",
    "last_name": "Kumar",
    "work_email": "ravi@demo.test",
    "country": "India",
    "department_id": 1,
    "job_title": "Software Engineer",
    "start_date": "2026-01-01",
    "bank_name": "HDFC Bank",
    "ifsc": "HDFC0001234",
    "account_number": "123456789012",
    "status": "active"
  },
  "compensation": {
    "components": [
      { "name": "Basic", "annual_amount": 1000000 },
      { "name": "Allowance", "annual_amount": 200000 }
    ]
  }
}
```

`ifsc` is optional. `status` is `onboarding` or `active`. `components` must contain at least one
row. Any supplied `annual_ctc` is ignored; the derived value is authoritative.

Success: `201 Created`

```json
{
  "data": {
    "id": 1,
    "employee_id": "EMP101",
    "first_name": "Ravi",
    "last_name": "Kumar",
    "work_email": "ravi@demo.test",
    "country": "India",
    "currency": "INR",
    "job_title": "Software Engineer",
    "start_date": "2026-01-01",
    "status": "active",
    "department": { "id": 1, "name": "Engineering" },
    "compensation": {
      "id": 1,
      "effective_date": "2026-01-01",
      "annual_ctc": "1200000.00",
      "currency": "INR",
      "components": [
        { "id": 1, "name": "Basic", "annual_amount": "1000000.00" },
        { "id": 2, "name": "Allowance", "annual_amount": "200000.00" }
      ]
    }
  }
}
```

Failures:

- `422 Unprocessable Content` with code `validation_failed` for duplicate employee ID or work email,
  missing/invalid fields, or an empty component list. `details` contains field messages.
- `401 Unauthorized` with code `invalid_token` without a valid access token.
- `403 Forbidden` with code `forbidden` for a non-HR user.
