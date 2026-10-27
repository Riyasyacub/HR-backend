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
  "employee_id": 1,
  "is_manager": false
}
```

`role` is `HR` or `standard_employee`. Managers are derived from the reporting hierarchy, not stored
as a role. `employee_id` is the linked employee record id, or `null` when the user has no employee
record. `is_manager` is `true` when that employee has at least one direct report.

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
      "employee_id": null,
      "is_manager": false
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
      "employee_id": null,
      "is_manager": false
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

Employee list and create access is HR only. Profile access is available to HR, the linked employee,
and a manager viewing an employee in their reporting subtree. Employee objects include a `manager`
summary with `id`, `employee_id`, and `name`, or `null`. The list omits compensation and bank
details; compensation is returned by the create response. Monetary values are decimal strings with
two places.

### GET `/api/v1/employees`

Any signed-in user. Results follow the viewer's scope: HR sees everyone, a manager sees their
subtree, an employee sees all colleagues (directory fields only), and a user without an employee
record gets an empty list. Returns employees ordered by `employee_id`. Results are
offset-paginated with `page` (default 1) and `per_page` (default 25, maximum 100).

Optional filters: `country`, `department_id`, `manager_id`, `status`, `search` (partial match on
name or employee ID), and `managers_only=true` (only employees with at least one direct report).

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
      "department": { "id": 1, "name": "Engineering" },
      "manager": null
    }
  ],
  "meta": { "page": 1, "per_page": 25, "total": 1 }
}
```

Failure: `401 Unauthorized` with code `invalid_token` without a valid access token, or
`403 Forbidden` with code `forbidden` for a non-HR user.

### GET `/api/v1/employees/:id`

HR can view any employee. A standard employee can view only the record linked to their own user.
A manager can view employees in their reporting subtree. Bank details and the latest compensation
with its components are included only for HR and the linked employee; manager views omit them.
HR and the linked employee also receive `phone`, `personal_email`, `address`, and
`emergency_contact`. Every profile includes `editable` (`true` when the viewer may update the
record). Any other employee URL returns `403 Forbidden`.

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
    "manager": null,
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
    "manager": null,
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

## S04 Reporting hierarchy

A manager is an employee with at least one direct report. Managers can read their full reporting
subtree, but cannot edit assignments or view compensation and bank details for their reports.

### PATCH `/api/v1/employees/:id`

HR can update HR-managed fields and contact fields. The linked employee can update only `phone`,
`personal_email`, `address`, and `emergency_contact`. For manager assignment, send `manager_id`;
send `null` to remove the manager. Omitting a field leaves it unchanged.

Sending a field the caller may not change returns `422` and nothing is saved:

```json
{
  "error": {
    "code": "read_only_fields",
    "message": "These fields cannot be changed: work_email",
    "details": ["work_email"]
  }
}
```

Request:

```json
{
  "employee": {
    "manager_id": 2
  }
}
```

Success: `200 OK` returns the employee detail, including the `manager` summary.

Failures:

- `422 Unprocessable Content` with code `validation_failed` when the manager does not exist, the
  employee is set as their own manager, or the assignment creates a reporting cycle. `details`
  contains the reason.
- `401 Unauthorized` with code `invalid_token` without a valid access token.
- `403 Forbidden` with code `forbidden` for a manager or standard employee.

### GET `/api/v1/employees/:id/leave_balances`

Same visibility as `GET /api/v1/employees/:id` (HR, the linked employee, or a manager of the
employee's subtree; otherwise `403`). Returns balanced leave types for `year` (default: current
year). `used` is net of reversals; `remaining = entitled - used`.

```json
{ "data": [{ "leave_type": "Earned", "entitled": 6, "used": 1, "remaining": 5 }] }
```

### GET `/api/v1/employees/team`

Manager only. Returns every employee in the manager's reporting subtree, at any depth, ordered by
`employee_id`. The manager is not included. Bank details and compensation are omitted. A user with
no direct reports receives `403 Forbidden`.

Success: `200 OK`

```json
{
  "data": [
    {
      "id": 2,
      "employee_id": "EMP102",
      "first_name": "Priya",
      "last_name": "Sharma",
      "work_email": "priya@demo.test",
      "country": "India",
      "currency": "INR",
      "job_title": "Product Manager",
      "start_date": "2026-01-01",
      "status": "active",
      "department": { "id": 2, "name": "Product" },
      "manager": { "id": 1, "employee_id": "EMP101", "name": "Arjun Patel" }
    }
  ]
}
```

A manager can open a subtree employee with `GET /api/v1/employees/:id`; that response omits bank
and compensation. Failure: `401 Unauthorized` with code `invalid_token` or `403 Forbidden` with code
`forbidden`.

## S06 Leave Excel import

### POST `/api/v1/leave_imports`

HR only. Multipart upload with a `file` field holding an `.xlsx` workbook (max 5 MB). The first
sheet needs the headers `employee_id`, `leave_date`, `leave_type`, and optionally `reason`. The
file is stored and processed by a background job.

Success: `202 Accepted`

```json
{
  "data": {
    "id": 7, "status": "queued", "total_rows": 0, "imported_rows": 0,
    "row_errors": [], "error_message": null, "created_at": "2026-10-27T22:00:00Z"
  }
}
```

A missing or non-`.xlsx` file returns `422` with code `validation_failed`. Non-HR users get `403`.

### GET `/api/v1/leave_imports/template`

HR only. Downloads `leave_template.xlsx` with the header row, one example row, and a `leave_type`
dropdown (earned, sick, casual, unpaid). Non-HR users get `403`.

### GET `/api/v1/leave_imports/:id`

HR only. Poll until `status` is `completed` or `failed`. `row_errors` lists rejected rows by sheet
line; valid rows are imported. A header problem sets `status: "failed"` and `error_message`.

```json
{
  "data": {
    "id": 7, "status": "completed", "total_rows": 2, "imported_rows": 1,
    "row_errors": [{ "line": 3, "errors": ["unknown employee EMP999"] }],
    "error_message": null, "created_at": "2026-10-27T22:00:00Z"
  }
}
```

### GET `/api/v1/leave_records`

Any signed-in user, scoped by policy: HR sees all records, a manager sees their own and their
subtree's, an employee sees their own, and a user without an employee record gets an empty list.
Newest first. Optional `leave_date` (`YYYY-MM-DD`) and `employee_id` (employee record id) filters; offset-paginated with `page` and
`per_page` (default 25, max 100).

```json
{
  "data": [
    {
      "id": 12, "leave_date": "2026-10-28", "leave_type": "Earned", "reason": "Family function",
      "payroll_deduction": false,
      "employee": { "id": 3, "employee_id": "EMP102", "name": "Priya Sharma" }
    }
  ],
  "meta": { "page": 1, "per_page": 25, "total": 1 }
}
```

### GET `/api/v1/leave_records/:id`

Same visibility as the list. A record outside the viewer's scope returns `403`.
