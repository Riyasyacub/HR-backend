# Prompt Log

## 2026-10-23

### Scaffold the Rails app

> Create a new Rails API-only app with PostgreSQL with the latest version.

Notes: Generated a Rails 8.1.4 API-only app with PostgreSQL 18.6, configured
`config/database.yml` for local TCP connections, and created the development and
test databases.

### Prompt log folder

> Create a separate folder inside this repo for logging my prompts.

Notes: Added the `prompts/` folder with this log and a short README describing the
format.

### HR discovery: Excel-based HR for 10,000 employees

> First I need to understand how HR managers work. Let's consider an HR team that
> manages around 10,000 employees within different countries, all maintained in
> Excel sheets. What are the problems they face every day? What will be their
> day-to-day work and how long will it take? Just explain these things to me.
> List these things for me.

Notes: Domain/discovery discussion only, no code changes. Covered the problems of
spreadsheet-based HR at scale, the recurring work of an HR team, and typical manual
effort and cycle times.

## 2026-10-24

### Product requirements for the eight in-scope HR workstreams

> In the above, except for statutory or compliance filing, benefits administration,
> performance and training admin, and audit and reconciliations: prepare a
> requirements document for the rest of the tasks for a software product.

Notes: Created `docs/requirements.md` covering employee master data, onboarding,
offboarding, payroll inputs, leave and attendance, reporting, employee queries, and
recruitment coordination, plus cross-cutting and non-functional requirements.

### Simplify requirements for a demo scope

> 1. This is a demo application, so we don't need this many roles. Maybe the hierarchy
> of employees, new candidates and then the HR team who manages everything on a single
> go. That's enough. 2. Here we have two different roles: employee and manager. In a
> real company it will be a hierarchy. Maybe a manager is reporting to a head manager,
> a senior manager, or someone like him. It should be based on hierarchy. The approval
> and requesting leave should be based on hierarchy not based on role. 3. Most
> country-based policies are not required right now. Only different countries, and they
> are moving from one country to another. That's fine. Country-based policies,
> country-based taxations, all those things are not required right now since this is a
> demo application. 4. Right now, there is no identity verification or something like
> that, only the source of proof: the Excel and the form that the new candidate is going
> to fill. No verifications of those fields which are entered by the candidate or from
> the Excel. We don't need that right now. 5. No payroll providers, too. We are just
> going to return that this is the monthly payroll that should be paid out, maybe in a
> separate Excel, pointing out each employee, his account, his account number, and bank
> details. 6. In integration only, email, time and attendance devices are enough.

Notes: Rewrote `docs/requirements.md` as v0.2 for a demo: three authenticated roles
(employee, manager, HR) plus candidates, hierarchy-based approvals, country as a plain
field with transfers, no verification, no country policies/tax, payroll as an Excel
payout export, and only email/attendance integrations.

### Apply demo decisions and resolve open questions

> open questions: 1. will provide will implementing the import feature. 2. India, USA,
> Canada 3. earned, sick, casual. 4. reset 5. yearly CTC is preferred while the breakup
> will be provided by the HR team, the excel will already have them. 6. yes 7. account
> number, ifsc, bank name 8. will give at the time of implementing the feature,
> basically (timestamps of first in and last out, employee id) 9. since it is demo, we
> gonna use only localhost now. 10. no 11. employee queries feature is not required for
> now. 12. a separate login for candidate is required, once selected, a new employee
> record will be created which will have reference of that candidate record. 13. we need
> a seed file of 10000 records of employees, 100 candidates, attendance of last 2 months.
> We may use Faker gem for it. 14. is based on country of the employee.
> wrong assumptions: candidates will have records.

Notes: Updated `docs/requirements.md` to v0.3: four authenticated roles including
candidates, candidate-to-employee reference, countries India/USA/Canada with
country-derived currency, earned/sick/casual/unpaid leave, annual CTC with imported
components, unpaid leave pay deduction, IFSC bank fields, localhost SMTP, employee
queries removed, and a 10,000-employee/100-candidate/2-month attendance seed.

### Generate sequential product stories and test cases

> With the above requirements file, generate product documents with multiple stories,
> each with a testable feature, along with test cases. The story should grow in a linear
> way, that the product should be tested in a sequential manner.

Notes: Added `docs/product-stories.md` (22 sequentially dependent stories, 158 test
cases) and `docs/test-plan.md` (execution order, environments, regression pack,
traceability), plus `docs/README.md` as the documentation index.

## 2026-10-25

### Add repository agent rules and prompt logging

> Generate an agents.md file for this repository, which should contain the basic logging
> of every prompt and several sets of development rules as follows:
> 1. Every implementation should follow the TDD approach using Rspec.
> 2. Every implementation should be split up into 50-line code chunks that I will review
> after every 50 lines. Once I review it, it should go on to the next 50-line chunk.
> 3. self-descriptive code with minimal comments; enterprise best practices (DRY, N+1
> awareness, heavy concurrency and race conditions); no unilateral decisions — ask
> questions first.

Notes: Added `AGENTS.md` with mandatory prompt logging, TDD/RSpec workflow, the 50-line
review gate, engineering and testing standards, and open decisions to confirm before
implementation.

### Confirm stack and working rules

> 1. We gonna use a React application for FE.
> 2. remove
> 3. use jwt
> 4. pundit
> 5. use mailhog
> 6. exclude specs/factories, just one line descriptions of tests before writing them
> 7. per story
> 8. will provide at S06 and S16

Notes: Recorded the stack decisions in `AGENTS.md`: React frontend, RSpec with Minitest
`test/` removed, JWT authentication, Pundit authorisation, Mailhog, production-only
50-line counts with one-line test descriptions, per-story commits, and fixtures at
S06/S16. Updated the requirements and test plan to name Mailhog.

### Confirm JWT, frontend, and API contract defaults

> JWT approach: jwt gem + password. Frontend setup: Vite + React + TS. API contract: v1 + offset paging.

Notes: Confirmed the S01 implementation defaults: `jwt` gem with `has_secure_password`,
Bearer access/refresh tokens and token-version revocation; React app in `frontend/` with
Vite, TypeScript, and Vitest/RTL; `/api/v1` with the agreed error envelope, offset
pagination, and CORS for `http://localhost:5173`. Updated `AGENTS.md` accordingly.

Setup chunk S00-1: added `rspec-rails`, `factory_bot_rails`, `faker`, `jwt`, `pundit`,
`bcrypt`, and `rack-cors`; removed the Minitest `test/` directory; configured FactoryBot,
the RSpec generators, Mailhog SMTP (`localhost:1025`), and the CORS initializer. Added two
smoke examples; `bundle exec rspec` passes (2 examples) and `bin/rubocop` is clean.

### Create separate React repository beside the backend

> create a FE repo parallel to the incubyte folder named incubyte-BE for the react app, we will build the FE along with the every story

Notes: Awaiting confirmation of the repository name (`incubyte-BE` versus `incubyte-FE`)
before scaffolding; no files created yet. Clarified in the next entry.

### Confirm frontend repo name and per-story commits

> Repo name: incubyte-FE. Initial git commit: yes. Story commits: one per story in both repos.

Notes: Created the sibling repo `../incubyte-FE` with Vite 8 + React 19 + TypeScript,
Vitest 5 + React Testing Library, jsdom, and Oxlint. Added a `/api` proxy to Rails on
port 3000, replaced the Vite demo with a minimal app shell, and added one smoke test.
`npm test` passes (1 test); `npm run build`, `npm run typecheck`, and `npm run lint` pass.
Initialized git and committed the scaffold as `18bd67d` (`chore: scaffold React frontend`).
Updated `AGENTS.md` to treat the frontend as a sibling repo, count React production lines,
run both test suites at each checkpoint, and commit once per story in both repos. Added a
frontend `AGENTS.md` that points to the backend rules and lists the frontend commands
(committed as `2f64beb`).

### Commit the pending setup changes

> commit now

Notes: Committed all pending backend setup and documentation changes as a single pre-S01
baseline commit, including RSpec/FactoryBot/Faker, JWT/Pundit/bcrypt/rack-cors, Mailhog,
CORS, the removed Minitest directory, and the updated agent instructions and docs. The
frontend repository was already clean.

### Start S01

> start S01

Notes: Reading the S01 story and preparing the first backend/frontend chunk plan; no code
written yet.

### Confirm S01 design choices

> Account model: user table for all employees (HR is also an employee), separate roles table for defining the roles (standard_employee, HR). Candidates will be a separate table.
> Session: Access JWT + refresh cookie (Recommended).
> Frontend: Router + Context (Recommended).
> Bootstrap: All eight accounts (Recommended).

Notes: Starting S01-1 with a roles table and a users table for every employee, including HR.
Seeding all eight demo accounts as users with names and countries; hierarchy, compensation,
and bank details stay with S03–S05. No code written yet.

Completed S01-1: added `roles` (`standard_employee`, `HR`) and `users` (role, name, email,
password digest, country, status, active, token version). Added `Role`/`User` models with
hashed passwords, normalised unique email, country/status/role validations, and idempotent
seeds for the eight demo accounts. Added model and seed specs; full suite passes (10 examples)
and RuboCop is clean. Development seed creates 8 users and 2 roles.

### Use shadcn/ui for frontend components

> one i missed, use shadcn for component library for FE, note it down

Notes: Recorded shadcn/ui with Tailwind CSS as the frontend component library in
`AGENTS.md`, `docs/test-plan.md`, and the frontend `AGENTS.md`/`README.md`. No packages
installed yet; setup belongs to the first S01 frontend chunk.

### Start S01-2

> start the next chunk

Notes: Starting the backend server-side session foundation: refresh-token hashing,
rotation, revocation, and the 8-hour inactivity window (1 minute in tests). No code
written yet.

Completed S01-2: added `user_sessions` with a SHA-256 refresh-token digest, `last_used_at`,
and `revoked_at`; added `UserSession.start_for`, `find_by_token`, lock-protected
`rotate!`, `active?`, `record_activity!`, and `revoke!`; added the 8-hour/1-minute
inactivity configuration; added the `User` association and time-helper support. New
specs pass (5 examples); full suite passes (15 examples); RuboCop is clean.

### Start S01-3

> proceed to the next chunk

Notes: Starting the signed access-token service: HS256, issuer/audience validation,
15-minute expiry, role, token version, and session id claims. No code written yet.

Completed S01-3: added `AccessToken` with HS256 signing, issuer/audience/expiry
verification, access-token type marker, role, token-version, and session-id claims;
added the 15-minute lifetime configuration. Added issue, expiry, tampering, wrong-issuer,
and wrong-audience specs. New specs pass (5 examples); full suite passes (20 examples);
RuboCop is clean.







### Start S01-4

> proceed to next chunk

Notes: Starting the sign-in API slice: credential verification, generic failure response,
access-token issuance, and the HttpOnly refresh cookie. No code written yet.

Completed S01-4: documented the S01 auth contract in `docs/api.md`; added
`POST /api/v1/auth/sign_in`, active-account credential checks, generic failure responses,
access-token issuance, a session-scoped HttpOnly/SameSite refresh cookie, credentialed CORS,
and cookie middleware. Added six request specs and the middleware configuration assertion.
New specs pass (6 examples); full suite passes (26 examples); RuboCop is clean. Production
lines: 49 of 50.

### Start S01-5

> proceed to next chunk

Notes: Starting refresh-token rotation and sign-out revocation. Planned production files:
`app/controllers/api/v1/auth/sessions_controller.rb`, `app/models/user_session.rb`, and
`config/routes.rb`. No code written yet.

Completed S01-5: added `POST /api/v1/auth/refresh` and `DELETE /api/v1/auth/sign_out`;
rotation is row-locked, bound to the presented refresh token, and refuses expired or revoked
sessions; inactive accounts are rejected and revoked; sign-out revokes the session and clears
the cookie idempotently. Added 10 examples (rotation race/expiry, refresh failures, sign-out)
and changed existing lookup/rotation specs. Full suite: 36 examples, 0 failures; RuboCop
clean. Production lines: 49 of 50.

### Start S01-6

> proceed to next chunk

Notes: Starting access-token authentication and `GET /api/v1/me`: Bearer parsing,
signature/claim validation, token-version and session checks, inactivity refresh, and
deactivated-account rejection. No code written yet.

Completed S01-6: added Bearer authentication to `ApplicationController` with signature,
expiry, issuer, audience, token-type, user-active, token-version, session-owner, revocation,
and inactivity checks; authenticated requests extend `last_used_at`; added `GET /api/v1/me`.
Added 11 current-user specs plus a sign-out-to-`/me` integration spec. Full suite: 48
examples, 0 failures; RuboCop clean. Production lines: 38 of 50.

### Start S01-7

> proceed to next chunk

Notes: Starting the frontend slice. Planned scope: install Tailwind CSS/shadcn and build the
typed auth API client (sign-in, current user, refresh, sign-out) with Vitest coverage. No
code written yet.

Completed S01-7: installed Tailwind CSS v4 and shadcn/ui (Vite plugin, alias, CSS theme,
generated button/utils), and added the typed auth client for sign-in and current-user with
credentialed requests, bearer headers, error envelopes, and a 204-safe response path. Added
four Vitest specs. Frontend tests (5), typecheck, lint, and build pass; backend suite (48)
and RuboCop pass. Production lines: 49 (`src/api/auth.ts`); generated shadcn files excluded.
Refresh and sign-out client calls move to S01-8 with the auth context.

### Start S01-8

> proceed to next chunk

Notes: Starting the auth state slice: add refresh/sign-out client calls and an
`AuthProvider` holding the in-memory session with sign-in/sign-out actions. Planned
production files: `src/api/auth.ts` and `src/auth/AuthContext.tsx`.

Completed S01-8: added `refreshAccessToken` and `signOut` client calls, plus `AuthProvider`
and `useAuth` with an in-memory session, sign-in, and sign-out. Sign-out clears local state
even when the API call fails. Added six API-client specs and four context specs; added React
Testing Library cleanup in `src/test/setup.ts`. Frontend tests (11), typecheck, lint, and
build pass; backend suite (48) and RuboCop pass. Production lines: 49 of 50 (`AuthContext.tsx`
40, `auth.ts` additions 9). Session restore and screens move to S01-9.

### Start S01-9

> proceed to next chunk

Notes: Starting session restore: refresh the session on mount, expose an auth loading
status, wire `AuthProvider` into the app entry point, and protect the refresh flow from
duplicate concurrent calls (React StrictMode). Planned production files:
`src/auth/AuthContext.tsx`, `src/api/auth.ts`, and `src/main.tsx`.

Completed S01-9: added mount-time refresh with `loading` / `authenticated` /
`unauthenticated` status, wired `AuthProvider` into `main.tsx`, and shared one in-flight
refresh promise so StrictMode cannot rotate the refresh token twice. Added a session-restore
context spec and a concurrent-refresh API spec. Frontend tests (13), typecheck, lint, and
build pass; backend suite (48) and RuboCop pass. Production lines: 29 of 50
(`AuthContext.tsx` +21, `auth.ts` +5, `main.tsx` +3). Sign-in screen and protected routes
move to S01-10.

### Start S01-10

> proceed to next chunk

Notes: Starting the first S01 screen: sign-in form, protected routing, and role-aware landing.
Checking the existing routing decisions before adding any dependency. No code written yet.

Completed S01-10: added the sign-in form with shadcn `Input` and `Button`, generic credential
errors, a loading state, and role-aware HR/employee dashboard headings. The form is selected
by auth status while URL routing is deferred to S01-11 to stay inside the 50-line gate. Added
four App integration specs covering loading, HR landing, employee landing, and invalid
credentials. Frontend tests (16), typecheck, lint, and build pass; backend suite (48) and
RuboCop pass. Production lines: 49 of 50 (`App.tsx` 13, `SignInPage.tsx` 36; generated
shadcn input excluded). Protected router and logout move to S01-11.

### Start S01-11

> proceed to next chunk

Notes: Starting URL routing and logout: install React Router (approved Router + Context
choice), add a protected dashboard route, redirect unauthenticated users to `/sign-in`,
redirect authenticated users away from the sign-in page, and add the logout action.
Planned production files: `src/main.tsx`, `src/App.tsx`, `src/pages/SignInPage.tsx`, and
`src/pages/DashboardPage.tsx`. Settings denial remains for the next chunk.

Completed S01-11: installed React Router, wrapped the app in `BrowserRouter`, added
`/sign-in` and protected `/dashboard` routes, redirected unauthenticated dashboard visits
to `/sign-in`, redirected authenticated users away from sign-in, and added the dashboard
logout action. Added location-aware App specs for guard redirect, HR/employee landing,
invalid credentials, and logout. Frontend tests (17), typecheck, lint, and build pass;
backend suite (48) and RuboCop pass. Production lines: 47 of 50 (`App.tsx` 23,
`DashboardPage.tsx` 13, `SignInPage.tsx` +4, `main.tsx` +7). HR settings and employee
denial move to S01-12.

### Start S01-12

> proceed to next chunk

Notes: Starting the role-denial slice: add an HR-only `/settings` route, redirect
employees away from it, and verify logout plus browser back does not restore protected
content. Planned production files: `src/App.tsx` and `src/pages/SettingsPage.tsx`.

Completed S01-12: added the HR-only `/settings` route with a `RequireHr` guard, an HR
settings placeholder, employee redirect back to `/dashboard`, and a browser-back assertion
after logout. Added three App specs; the HR settings case was the red phase. Frontend tests
(20), typecheck, lint, and build pass; backend suite (48) and RuboCop pass. Production
lines: 17 of 50 (`App.tsx` +9, `SettingsPage.tsx` 8). S01 frontend slice is complete;
story-level regression, documentation, and the two commits remain after sign-off.

### Start S01 sign-off

> proceed to next chunk

Notes: Starting S01 story sign-off: run the regression smoke pack in both repositories,
reconcile the S01 acceptance criteria and test table, update documentation, review the full
diff, and prepare the two story commits. No production code is planned.

Completed S01 sign-off: mapped AC-01–AC-06 to the backend request/model specs and the React
routing/sign-in specs. Final checks: backend 48 examples, RuboCop clean, Brakeman 0 warnings;
frontend 20 examples, typecheck, lint, and production build pass. Updated `docs/README.md`,
the root `AGENTS.md` current state/decisions, and the frontend README. No blocking defects.
Committing both repositories as the S01 story commit. Untracked RubyMine/RBS artifacts were
left untouched and excluded.

## 2026-10-26

### Start S02

> start the next story

Notes: Started S02. Confirmed with the user: expose department deactivation only until S03,
add minimal audit entries now for TC-S02-04, and keep countries as an immutable code lookup.
S02-1 adds the Country lookup, Pundit authorization foundation, and the HR-only countries
endpoint with request/model specs. Production lines: 49 of 50. Departments, leave types,
audit entries, and the React settings screens remain.

### API version namespace in routes

> in routes "api/v1/" is common namespace right?

Notes: Confirmed that `/api/v1` should be expressed as a Rails `api`/`v1` namespace. The current
routes still spell the prefix literally on each line; no code changed in this turn.

### Namespace the API routes

> yes do yhat

Notes: Completed S02-2. Moved the routes into `namespace :api` / `namespace :v1`; all existing
URLs and named path helpers remain valid. Added the departments table with case-insensitive
unique name/code indexes, the Department model and Pundit policy, and HR-only list/create
endpoints. Production lines: 50 of 50. Rename, deactivate, leave types, audit entries, and the
React settings screens remain.

### Continue S02 departments

> proceed to next chunk

Notes: Completed S02-3. Added HR-only rename and deactivation actions. Renames trim the name,
reject case-insensitive duplicates, and leave the code unchanged. Deactivation keeps the row and
sets `active: false`; no DELETE route exists. Production lines: 33. Leave types, audit entries,
and the React settings screen remain.

### Continue S02 leave types

> proceed to next chunk

Notes: Completed S02-4a. Added the leave_types table with a non-negative check constraint, the
four fixed types, balance tracking rules, ordered seed data, and an HR-only list endpoint.
Production lines: 50 of 50. Entitlement updates and audit entries remain in S02-4b.

### Continue S02 entitlement updates

> proceed to next chunk

Notes: Completed S02-4b. Added HR-only entitlement updates with transactional audit entries,
negative/unpaid validation, and no audit for unchanged values. The audit_entries table stores
actor, polymorphic auditable record, action, and JSONB change set. Production lines: 33.
The React settings screen remains.

### Start S02 settings screen

> proceed to next chunk

Notes: Completed S02-5. Exported the existing API request helper, added the settings client and
an HR settings countries section backed by `GET /settings/countries`. Added API and UI tests
for the bearer token, the three country/currency pairs, and the absence of editable controls.
Production lines: 46. Department management and leave-type editing remain.

### Departments settings client

> proceed to next chunk

Notes: Completed S02-6 as the departments API client: list, create, rename, and deactivate calls
with the HR bearer token, plus tests for each contract. The read-only departments list moved to
S02-7 to keep this chunk within the 50-line limit. Production lines: 40.

### Departments settings screen

> proceed to next chunk

Notes: Completed S02-7. The HR settings page now loads departments alongside countries, shows active
and inactive departments, creates departments through the API, and surfaces duplicate-name errors.
Production lines: 42. Rename and deactivate controls remain.

### Department rename and deactivate controls

> proceed to next chunk

Notes: Completed S02-8. Departments can now be renamed inline and deactivated. Duplicate rename
errors keep the edit form open with the entered value, and inactive rows hide both actions.
Production lines: 44. Backend unchanged.

### Leave types settings screen

> proceed to next chunk

Notes: Completed S02-9. Leave types now load with countries and departments. Balanced rows accept
integer entitlement updates; blank, negative, and non-integer values are rejected before the API,
and Unpaid is shown without an entitlement. Production lines: 43. S02 UI is complete.

### S02 story sign-off

> proceed to next chunk

Notes: Completed S02 sign-off checks. Backend: 85 examples, 0 failures; RuboCop clean; Zeitwerk OK;
Brakeman 0 warnings. Frontend: 37 tests, typecheck, lint, and build green. Updated the current-stage
notes in README and AGENTS.md and removed the stale S02-in-progress API note. TC-S02-01 through
TC-S02-06 are covered; AC-03's active-employee guard remains deferred to S03 with no delete route.
Regression smoke pack starts at S03, so only existing S01 paths were exercised. Commit pending
explicit approval.

### Commit S02 and start S03

> commit and start next story

Notes: Approved to commit S02 in both repositories. After the commits, starting S03 planning by reading
the story, requirements, and current employee/auth models.
