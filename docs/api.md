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
  "country": "India"
}
```

`role` is `HR` or `standard_employee`. Managers are derived from the reporting hierarchy, not stored
as a role.

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
      "country": "India"
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
      "country": "India"
    }
  }
}
```

Failure: `401 Unauthorized` with code `invalid_token` when the access token is missing, expired,
invalid, revoked, belongs to an inactive account, or no longer matches the user's token version.
Each authenticated request also extends the session's inactivity window.
