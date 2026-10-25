# HR Demo — Product Stories and Test Cases

| Field | Value |
|---|---|
| Version | 1.0 |
| Date | 2026-10-24 |
| Source | `docs/requirements.md` v0.3 |
| Status | Ready for build |

## How to use this document

- Stories are numbered **S01–S22** and must be built and tested **in order**. Each story assumes every earlier story is complete and its tests pass.
- Every story delivers one testable feature slice, lists its acceptance criteria, and includes its test cases.
- Test case IDs use `TC-S<story>-<number>`. Types: **H** happy path, **N** negative, **E** edge, **P** permission, **I** integration, **PF** performance.
- Test data is created progressively: accounts and records from earlier stories are reused by later stories.
- The companion execution plan is in `docs/test-plan.md`.

## Story map

| # | Story | Epic | Depends on |
|---|---|---|---|
| S01 | Sign-in and role-based access | Foundation | — |
| S02 | HR configuration: countries, departments, leave types | Foundation | S01 |
| S03 | Create and manage employee records | People | S02 |
| S04 | Reporting hierarchy and manager scope | People | S03 |
| S05 | Employee self-service, directory, and change history | People | S04 |
| S06 | Employee Excel import with compensation | People | S04 |
| S07 | Candidate registration, login, and profile | Hiring | S01 |
| S08 | Job openings | Hiring | S07 |
| S09 | Job applications | Hiring | S08 |
| S10 | Recruitment pipeline, interviews, and offers | Hiring | S09 |
| S11 | Convert a hired candidate to an employee | Hiring | S10, S03 |
| S12 | Onboarding checklist, invite, and activation | Onboarding | S11 |
| S13 | Leave balances and ledger | Leave | S12 |
| S14 | Leave request submission | Leave | S13 |
| S15 | Hierarchy-based leave approval and team calendar | Leave | S14 |
| S16 | Attendance CSV import | Attendance | S12 |
| S17 | Attendance exceptions and reconciliation | Attendance | S16, S15 |
| S18 | Monthly payroll run | Payroll | S15, S17 |
| S19 | Payroll Excel export and history | Payroll | S18 |
| S20 | Offboarding and access deactivation | Offboarding | S12, S19 |
| S21 | Reporting dashboards and exports | Reporting | S20 |
| S22 | Demo seed data and scale verification | Demo readiness | S21 |

## Test accounts and fixtures used throughout

| Account | Role | Notes |
|---|---|---|
| `hr@demo.test` / `Demo@1234` | HR | Bootstrap account, created in S01 |
| `meera@demo.test` | Manager (top level, India) | No manager; leave routes to HR |
| `arjun@demo.test` | Manager (India, reports to Meera) | Has Priya as a direct report |
| `priya@demo.test` | Employee (India, reports to Arjun) | Used for leave and attendance tests |
| `robert@demo.test` | Manager (USA) | One direct report: John |
| `john@demo.test` | Employee (USA, reports to Robert) | Used for payroll tests |
| `carol@demo.test` | Manager (Canada) | One direct report: Emily |
| `emily@demo.test` | Employee (Canada, reports to Carol) | Used for offboarding tests |
| `nisha@example.test` / `Candidate@123` | Candidate | Registered in S07 |

Fixtures: `employees_sample.xlsx`, `employees_invalid.xlsx`, `attendance_sample.csv`,
`resume.pdf`, `offer_letter.pdf`. The final employee and attendance formats are confirmed when
S06 and S16 are implemented (per requirements §13).

All demo accounts use `Demo@1234` unless noted. The bootstrap creates the authentication user and a
minimal employee record (name, country, department, status, sample CTC/components, and bank details)
so authentication and later stories have stable data. Stories S03–S06 add new records on top of it.

---

## S01 — Sign-in and role-based access

| | |
|---|---|
| Epic | Foundation |
| Priority | P0 |
| Depends on | — |
| Covers | XC-03, NFR-04, NFR-05 |

**Story**
As an HR user or employee, I want to sign in with my credentials and land on the correct dashboard,
so that I only see the data my role allows.

**Feature**
- Email and password authentication for HR and employees (candidates added in S07).
- Role-aware landing page: HR dashboard vs employee dashboard.
- Logout, session expiry after 8 hours of inactivity, and denial of direct URL access to other roles' pages.
- Passwords stored with a modern hash.

**Acceptance criteria**

- **AC-01** A valid HR login lands on the HR dashboard; a valid employee login lands on the employee dashboard.
- **AC-02** Invalid credentials show a generic error and create no session.
- **AC-03** Unauthenticated users are redirected to sign-in; authenticated users are denied pages outside their role.
- **AC-04** Logout ends the session; using the browser back button does not restore an authenticated page.
- **AC-05** A session expires after the configured inactivity window (8 hours in production, 1 minute in tests).
- **AC-06** Password hashes are stored in the database; no plaintext password exists in any table or log.

**Test cases**

| ID | Type | Given | When | Then |
|---|---|---|---|---|
| TC-S01-01 | H | Bootstrap HR account exists | Sign in with `hr@demo.test` / `Demo@1234` | HR dashboard loads; session cookie is set |
| TC-S01-02 | H | Bootstrap employee account exists | Sign in with `priya@demo.test` | Employee dashboard loads; no HR menu items are visible |
| TC-S01-03 | N | Bootstrap HR account exists | Sign in with a wrong password | Generic "invalid email or password" message; no session; no hint about which field is wrong |
| TC-S01-04 | P | Signed in as Priya (employee) | Open `/settings` directly | Request is denied (403 or redirect) and no settings data is shown |
| TC-S01-05 | E | Signed in as HR | Log out, then press browser Back | Sign-in page is shown; protected content is not restored |
| TC-S01-06 | E | Session timeout set to 1 minute | Stay idle for 70 seconds, then open a protected page | User is signed out and redirected to sign-in |

---

## S02 — HR configuration: countries, departments, leave types

| | |
|---|---|
| Epic | Foundation |
| Priority | P0 |
| Depends on | S01 |
| Covers | XC-10, EMP-05, LVE-01, R-16, R-17 |

**Story**
As an HR user, I want to maintain the fixed country list, departments, and leave types, so that
employee and leave records use consistent values.

**Feature**
- Read-only country reference data: India → INR, USA → USD, Canada → CAD.
- Department CRUD (create, rename, deactivate) with unique names.
- Leave types: earned, sick, casual, unpaid, with editable default annual entitlements; unpaid has no entitlement.
- Settings are restricted to HR.

**Acceptance criteria**

- **AC-01** Exactly three countries are available, each mapped to its currency; currency cannot be edited.
- **AC-02** HR can create and rename a department; duplicate names are rejected.
- **AC-03** A department with active employees cannot be deleted (it can only be deactivated).
- **AC-04** Default entitlements for earned, sick, and casual are non-negative integers and editable; unpaid has no balance.
- **AC-05** Employees and managers cannot open configuration pages.

**Test cases**

| ID | Type | Given | When | Then |
|---|---|---|---|---|
| TC-S02-01 | H | Signed in as HR | Open Countries | India, USA, Canada are listed with INR, USD, CAD; fields are read-only |
| TC-S02-02 | H | Signed in as HR | Create department "Engineering" with code "ENG" | Department is saved and available for employee assignment |
| TC-S02-03 | N | "Engineering" exists | Create another department named "Engineering" | Validation error; no duplicate is created |
| TC-S02-04 | H | Leave type "Earned" exists | Change the default entitlement to 18 | Value saves; audit entry records the change |
| TC-S02-05 | N | Signed in as HR | Enter a negative entitlement | Validation error; value is not saved |
| TC-S02-06 | P | Signed in as Priya (employee) | Open `/settings` | Access denied |

---

## S03 — Create and manage employee records

| | |
|---|---|
| Epic | People |
| Priority | P0 |
| Depends on | S02 |
| Covers | EMP-01, EMP-05, EMP-07, EMP-08, EMP-10, DR-04, DR-05, DR-08 |

**Story**
As an HR user, I want to create an employee with personal, job, compensation, and bank details, so
that the employee has one authoritative record.

**Feature**
- Manual employee creation with required fields: employee ID, first/last name, work email, country, department, job title, start date, annual CTC, at least one component, bank name, account number, status.
- Country drives currency automatically.
- Unique employee ID and work email.
- CTC component warning when components do not sum to CTC.
- Employee-level access to their own record; HR-only editing of compensation and bank data.

**Acceptance criteria**

- **AC-01** An employee can be created with all required fields and appears in the employee list.
- **AC-02** Currency is set automatically from country and cannot be edited independently.
- **AC-03** Duplicate employee ID or work email is rejected with a field-level error.
- **AC-04** Annual CTC and components are stored; a mismatch shows a non-blocking warning.
- **AC-05** The employee can view their own profile, including CTC and bank details, but cannot edit them.
- **AC-06** An employee has a status of `onboarding` or `active` and a start date.

**Test cases**

| ID | Type | Given | When | Then |
|---|---|---|---|---|
| TC-S03-01 | H | Signed in as HR; Engineering and India exist | Create employee EMP101, Ravi Kumar, `ravi@demo.test`, India, annual CTC 1,200,000, component Basic 1,200,000 | Employee is saved; currency is INR; list shows Ravi |
| TC-S03-02 | H | Signed in as HR | Create a Canadian employee | Currency is CAD automatically; no currency selector is shown |
| TC-S03-03 | N | Employee EMP101 exists | Create another employee with ID EMP101 | Validation error on employee ID; nothing is saved |
| TC-S03-04 | N | Employee `ravi@demo.test` exists | Create an employee with the same work email | Validation error on email |
| TC-S03-05 | E | Signed in as HR | Enter CTC 1,200,000 with components totalling 1,000,000 | Record saves with a visible warning about the component mismatch |
| TC-S03-06 | P | Signed in as Priya | Open her own profile, then attempt to edit CTC | CTC and bank fields are read-only; contact fields (if editable) save |
| TC-S03-07 | P | Signed in as Priya | Open another employee's profile URL | Access denied |

---

## S04 — Reporting hierarchy and manager scope

| | |
|---|---|
| Epic | People |
| Priority | P0 |
| Depends on | S03 |
| Covers | XC-02, EMP-03, EMP-04, R-01 to R-06, R-14 |

**Story**
As an HR user, I want to assign managers and maintain a hierarchy, so that teams, visibility, and
leave approvals follow the reporting line.

**Feature**
- Assign, change, and remove a direct manager.
- Reject self-management and reporting cycles.
- Manager capability derived from having direct reports.
- Managers can view their full subtree; HR sees all; unrelated employees see nothing.
- HR can reassign an employee's manager.

**Acceptance criteria**

- **AC-01** An employee can have exactly one direct manager, and the manager must be an existing employee.
- **AC-02** Assigning yourself or any subordinate (direct or indirect) as manager is rejected.
- **AC-03** Reassigning a manager updates the hierarchy immediately in lists, profiles, and dashboards.
- **AC-04** A manager can view employees in their subtree but not employees outside it.
- **AC-05** A user with no direct reports cannot access manager-only pages.
- **AC-06** Managers cannot edit compensation, bank details, country, or manager assignments.

**Test cases**

| ID | Type | Given | When | Then |
|---|---|---|---|---|
| TC-S04-01 | H | Priya and Arjun exist | Set Arjun as Priya's manager | Hierarchy shows Priya under Arjun; Priya's profile shows the manager |
| TC-S04-02 | N | Priya reports to Arjun | Set Priya as Arjun's manager | Cycle detected; change is rejected |
| TC-S04-03 | N | Priya exists | Set Priya as her own manager | Validation error |
| TC-S04-04 | H | Priya reports to Arjun; Arjun reports to Meera | Reassign Priya to Meera | Priya's subtree view and future approvals use Meera |
| TC-S04-05 | P | Arjun manages Priya; Robert manages John | Sign in as Arjun and open John's profile | Access denied; Arjun sees Priya but not John |
| TC-S04-06 | P | Priya has no reports | Sign in as Priya and open manager team view | Access denied |
| TC-S04-07 | P | Signed in as Arjun (manager) | Attempt to change Priya's salary via API | Request rejected |

---

## S05 — Employee self-service, directory, and change history

| | |
|---|---|
| Epic | People |
| Priority | P0 |
| Depends on | S04 |
| Covers | EMP-05, EMP-06, EMP-11, XC-07, XC-09 |

**Story**
As an employee, I want to maintain my contact details and find colleagues in the directory, and as
HR I want to see who changed what, so that records stay accurate and traceable.

**Feature**
- Employee self-service for phone, personal email, address, and emergency contact.
- Read-only employee ID, work email, job, compensation, and bank data.
- Directory with search and filters by country, department, manager, and status.
- Change history with actor, timestamp, field, old value, and new value.
- Permission-aware directory results.

**Acceptance criteria**

- **AC-01** Self-service changes save immediately and are visible to HR.
- **AC-02** Employee ID, work email, compensation, bank, and hierarchy fields cannot be edited by the employee.
- **AC-03** Directory filters return exactly the matching employees and respect the viewer's scope.
- **AC-04** Every field change creates an audit entry showing old and new values.
- **AC-05** Salary, CTC, and bank details never appear in directory cards, search results, or manager views.
- **AC-06** A manager's directory view is limited to their subtree.

**Test cases**

| ID | Type | Given | When | Then |
|---|---|---|---|---|
| TC-S05-01 | H | Signed in as Priya | Change phone to `+91-98765-43210` | Value saves and is visible to HR |
| TC-S05-02 | N | Signed in as Priya | Try to change work email | Field is read-only and the request is rejected |
| TC-S05-03 | H | Employees exist in India, USA, Canada | Filter directory by country = USA | Only USA employees are listed |
| TC-S05-04 | H | Directory has 20+ employees | Search by partial name | Matching employees are returned, scoped to the viewer |
| TC-S05-05 | H | HR changes Priya's department | Open change history | Entry shows actor, timestamp, old department, new department |
| TC-S05-06 | P | Signed in as Arjun (manager) | Open directory | Only Arjun's subtree is listed |
| TC-S05-07 | P | Signed in as Priya | Search directory | Salary and bank columns are absent; other employees are limited to directory fields |

---

## S06 — Employee Excel import with compensation

| | |
|---|---|
| Epic | People |
| Priority | P0 |
| Depends on | S04 |
| Covers | EMP-01, EMP-02, EMP-07, EMP-08, XC-06, NFR-02 |

**Story**
As an HR user, I want to import employees and their CTC breakup from Excel, so that the existing
workbook becomes the initial source of records.

**Feature**
- Downloadable workbook template with an `Employees` sheet and a `Compensation` sheet.
- Upload, preview, validate, and import with a row-level error report.
- Manager references resolved in a second pass, including managers in the same file.
- Duplicate employee IDs or work emails rejected per row; valid rows still import.
- Bank name, IFSC, and account number imported from the employee sheet.

**Acceptance criteria**

- **AC-01** The template contains all required employee columns and the compensation component columns documented in requirements §9.
- **AC-02** Preview lists creates and errors without writing to the database.
- **AC-03** Importing a valid file creates every employee with the correct country, currency, manager, CTC, components, and bank details.
- **AC-04** Invalid rows are skipped and listed with row number and reason; valid rows are imported.
- **AC-05** Importing a manager and their report in the same file resolves the hierarchy correctly.
- **AC-06** Re-importing the same file does not create duplicates for rejected rows; existing IDs are reported as duplicates.
- **AC-07** Only HR can access import.

**Test cases**

| ID | Type | Given | When | Then |
|---|---|---|---|---|
| TC-S06-01 | H | Signed in as HR; template downloaded | Upload `employees_sample.xlsx` with 5 valid rows | Preview shows 5 creates; import succeeds; 5 employees exist |
| TC-S06-02 | N | File has a row missing work email | Upload and preview | Row 3 is listed with "work email required"; no record is written for it |
| TC-S06-03 | E | File contains a new manager and a report in the same workbook | Import the file | Both are created and the report's manager is the new manager |
| TC-S06-04 | N | File contains an employee ID that already exists | Import | That row is reported as a duplicate; other valid rows import |
| TC-S06-05 | H | File includes compensation components Basic and Allowance | Import | Employee's monthly gross derives from both components |
| TC-S06-06 | H | File includes bank fields for a Canadian employee | Import | Bank name, account number, and blank IFSC are stored; currency is CAD |
| TC-S06-07 | P | Signed in as Arjun (manager) | Open the import page or POST an import | Access denied |

---

## S07 — Candidate registration, login, and profile

| | |
|---|---|
| Epic | Hiring |
| Priority | P0 |
| Depends on | S01 |
| Covers | REC-02, REC-03, REC-04, XC-03, NFR-04, R-08 |

**Story**
As a candidate, I want to register and sign in to my own account, so that I can apply for roles and
track my applications.

**Feature**
- Candidate self-registration with name, email, phone, country, and password.
- Candidate login and logout on the same authentication system, with candidate-only access.
- Profile editing; email becomes read-only after registration.
- Password reset by email using local SMTP and the local mail catcher.

**Acceptance criteria**

- **AC-01** Registration creates a candidate record and signs the candidate in.
- **AC-02** Duplicate email registration is rejected.
- **AC-03** A candidate can sign in, view their profile, and edit phone and country.
- **AC-04** Password reset sends a working, single-use link to the local mail catcher.
- **AC-05** Candidates cannot access employee, manager, or HR pages or data.
- **AC-06** A candidate has a distinct record from any employee with the same name.

**Test cases**

| ID | Type | Given | When | Then |
|---|---|---|---|---|
| TC-S07-01 | H | No candidate with `nisha@example.test` | Register Nisha Rao with valid details | Candidate record created; signed in; candidate dashboard shown |
| TC-S07-02 | N | Nisha is registered | Register again with `nisha@example.test` | "Email already registered" error; no second record |
| TC-S07-03 | H | Nisha registered | Sign in with correct password | Candidate dashboard loads with profile access |
| TC-S07-04 | I | Nisha registered | Request password reset | Email appears in the local mail catcher; link sets a new password; the link cannot be reused |
| TC-S07-05 | P | Signed in as Nisha | Open `/employees` or an HR page | Access denied |
| TC-S07-06 | N | Signed in as Nisha | Attempt to change email | Field is read-only and the request is rejected |

---

## S08 — Job openings

| | |
|---|---|
| Epic | Hiring |
| Priority | P0 |
| Depends on | S07 |
| Covers | REC-01, REC-11 |

**Story**
As an HR user, I want to create and manage job openings, so that candidates can see and apply for
current roles.

**Feature**
- Job opening create/edit with title, country, department, description, and status (open/closed).
- Candidate-facing list of open openings with detail pages.
- Closed openings hidden from candidates and rejected for new applications.
- Only HR can manage openings.

**Acceptance criteria**

- **AC-01** HR can create and edit an opening with all required fields.
- **AC-02** Only openings with status `open` appear to candidates.
- **AC-03** Closing an opening removes it from the candidate list.
- **AC-04** Currency is implied by the opening's country.
- **AC-05** Employees and candidates cannot create or edit openings.

**Test cases**

| ID | Type | Given | When | Then |
|---|---|---|---|---|
| TC-S08-01 | H | Signed in as HR | Create "Software Engineer", India, Engineering, open | Opening is saved and listed |
| TC-S08-02 | H | Signed in as HR | Edit the description | Change is saved and visible on the detail page |
| TC-S08-03 | H | Opening is open | Change status to closed | Opening disappears from the candidate list |
| TC-S08-04 | H | Two openings, one closed | Sign in as Nisha and open the openings list | Only the open opening is listed |
| TC-S08-05 | P | Signed in as Nisha | POST to create an opening | Request denied |
| TC-S08-06 | P | Signed in as Nisha | Open a closed opening's URL directly | Not found or closed message; no apply action |

---

## S09 — Job applications

| | |
|---|---|
| Epic | Hiring |
| Priority | P0 |
| Depends on | S08 |
| Covers | REC-02, REC-04, XC-08 |

**Story**
As a candidate, I want to apply to an open role with my CV, so that HR can review my application.

**Feature**
- Application form pre-filled from the candidate profile, with CV upload and application answers.
- One application per candidate per opening; duplicate attempts rejected.
- File limits and allowed types for CVs.
- Candidate dashboard listing own applications and current stage.
- Candidates cannot view another candidate's application.

**Acceptance criteria**

- **AC-01** A valid application is created and linked to the signed-in candidate and the opening.
- **AC-02** A duplicate application to the same opening is rejected.
- **AC-03** Applications to closed openings are rejected.
- **AC-04** CV upload accepts configured types and rejects unsupported types or oversize files.
- **AC-05** The candidate dashboard shows only the candidate's own applications and stage.
- **AC-06** Application records include candidate, opening, CV, date, and initial stage `Applied`.

**Test cases**

| ID | Type | Given | When | Then |
|---|---|---|---|---|
| TC-S09-01 | H | Nisha signed in; Software Engineer opening is open | Apply with `resume.pdf` | Application created in stage Applied; visible on Nisha's dashboard |
| TC-S09-02 | N | Nisha already applied to Software Engineer | Apply again to the same opening | Rejected with "already applied" |
| TC-S09-03 | N | Opening is closed | Apply via the direct URL | Rejected; no application is created |
| TC-S09-04 | N | Opening is open | Upload `resume.exe` | Validation error; upload rejected |
| TC-S09-05 | P | Nisha and another candidate both applied | Sign in as Nisha and open the other application URL | Access denied |
| TC-S09-06 | E | Nisha applies to a second, different opening | Submit | A second application is allowed and listed separately |

---

## S10 — Recruitment pipeline, interviews, and offers

| | |
|---|---|
| Epic | Hiring |
| Priority | P0 |
| Depends on | S09 |
| Covers | REC-05 to REC-10, XC-04, R-17 |

**Story**
As a recruiter in the HR team, I want to move candidates through stages, record interviews, and
issue offers, so that hiring is tracked and communicated consistently.

**Feature**
- Pipeline stages: Applied → Screening → Interview → Offer → Hired; Rejected from any stage.
- Stage changes timestamped and listed in history.
- Internal notes visible to HR only.
- Interview date and interviewer recorded; candidate gets an email.
- Offer details: annual CTC, components, start date, country, manager, department; currency from country.
- Stage-change and rejection emails using editable templates.

**Acceptance criteria**

- **AC-01** HR can advance or reject an application, and every transition is timestamped.
- **AC-02** Candidate sees the current stage but never internal notes.
- **AC-03** Recording an interview sends the candidate an email to the local mail catcher.
- **AC-04** Moving to Offer requires annual CTC and start date; currency follows the opening/offer country.
- **AC-05** Rejecting sends a rejection email and stops further stage changes.
- **AC-06** Offer records can only be created by HR.

**Test cases**

| ID | Type | Given | When | Then |
|---|---|---|---|---|
| TC-S10-01 | H | Nisha's application is in Applied | Move to Screening | Stage updates; history shows timestamp and actor |
| TC-S10-02 | H | Application in Screening | Add internal note "Strong portfolio" | Note visible to HR; not visible on the candidate dashboard |
| TC-S10-03 | I | Application in Interview | Record interview on 2026-11-05 with interviewer Arjun | Candidate email appears in the mail catcher with date and interviewer |
| TC-S10-04 | N | Application in Interview | Move to Offer without CTC | Validation error; stage does not change |
| TC-S10-05 | H | CTC 1,200,000 and start date provided | Move to Offer | Offer saved; currency INR from the India opening |
| TC-S10-06 | H | Application in Screening | Reject with reason | Rejection email sent; candidate dashboard shows Rejected; further stage moves blocked |
| TC-S10-07 | P | Signed in as Nisha | Open the pipeline board | Access denied |

---

## S11 — Convert a hired candidate to an employee

| | |
|---|---|
| Epic | Hiring |
| Priority | P0 |
| Depends on | S10, S03, S04 |
| Covers | REC-09, EMP-13, DR-09, BR-REC-03, BR-REC-06 |

**Story**
As an HR user, I want to convert a hired candidate into an employee record, so that hiring hands
off to onboarding without re-entering data.

**Feature**
- Conversion action available only for applications in `Hired`.
- Employee pre-filled from candidate and offer: name, email, phone, country, department, manager, CTC, components, start date.
- Employee record stores a permanent reference to the candidate; both records show the link.
- Conversion creates an onboarding checklist (completed in S12).
- Duplicate conversion blocked.

**Acceptance criteria**

- **AC-01** Only a `Hired` application can be converted.
- **AC-02** The employee record is pre-filled and carries `candidate_id`.
- **AC-03** Candidate and employee views link to each other.
- **AC-04** Converting the same application twice is blocked.
- **AC-05** Conversion creates the employee with status `onboarding` and an onboarding checklist.
- **AC-06** No candidate password or candidate login is carried over to the employee account.

**Test cases**

| ID | Type | Given | When | Then |
|---|---|---|---|---|
| TC-S11-01 | H | Nisha's application is Hired with offer data | Convert to employee | Employee created in `onboarding`; name, country, manager, CTC, start date match the offer |
| TC-S11-02 | N | Application is in Offer | Click convert | Action unavailable/rejected |
| TC-S11-03 | H | Employee created from Nisha | Open the employee and candidate records | Employee shows candidate reference; candidate shows created employee |
| TC-S11-04 | N | Nisha already converted | Convert again | Rejected; no second employee |
| TC-S11-05 | H | Conversion complete | Open the onboarding tab | Checklist exists with pending tasks |
| TC-S11-06 | P | Signed in as Nisha (candidate) | Try to convert or open the employee record | Access denied |

---

## S12 — Onboarding checklist, invite, and activation

| | |
|---|---|
| Epic | Onboarding |
| Priority | P0 |
| Depends on | S11 |
| Covers | ONB-01 to ONB-08, OFF-adjacent status rules |

**Story**
As an HR user, I want an onboarding checklist, document collection, and account invite, so that a
new employee is fully ready and activated on the start date.

**Feature**
- Checklist generated on conversion with task owner (HR, manager), due dates relative to start date.
- Document upload: contract, ID, policy acknowledgement.
- Bank and compensation confirmation before activation.
- Employee invite email; login disabled before the start date.
- Activation requires mandatory tasks complete or HR-waived.
- Reminder emails for overdue tasks; no-show cancellation deactivates access.

**Acceptance criteria**

- **AC-01** Conversion creates tasks with owners and due dates.
- **AC-02** Documents attach to the employee and show pending/completed state.
- **AC-03** The invite email is sent only after the employee record exists; login works only from the start date.
- **AC-04** Activation is blocked while mandatory tasks are incomplete, unless HR waives with a reason.
- **AC-05** On activation, status becomes `active` and default leave balances are created.
- **AC-06** Reminder emails are sent for overdue tasks and stop after completion.
- **AC-07** No-show cancellation sets a closed status and blocks login.

**Test cases**

| ID | Type | Given | When | Then |
|---|---|---|---|---|
| TC-S12-01 | H | Employee created from a hired candidate | Open onboarding | Tasks exist with correct owners and dates |
| TC-S12-02 | H | Onboarding in progress | Upload contract and ID | Documents attach; tasks move to complete |
| TC-S12-03 | I | Employee start date is in the future | Send invite, then try to sign in | Invite email appears in the mail catcher; login is denied until the start date |
| TC-S12-04 | N | Mandatory document task incomplete | Attempt activation | Activation blocked with the missing item listed |
| TC-S12-05 | H | HR waives the incomplete task with reason "joined with prior verified docs" | Activate | Employee becomes `active`; leave balances are created |
| TC-S12-06 | E | Task overdue by 2 days | Run reminders | One reminder email per overdue task; none after completion |
| TC-S12-07 | E | Onboarding in progress | Mark as no-show | Status closed; login blocked; no payroll inclusion |

---

## S13 — Leave balances and ledger

| | |
|---|---|
| Epic | Leave |
| Priority | P0 |
| Depends on | S12 |
| Covers | LVE-01, LVE-02, LVE-11, LVE-12, BR-LVE-05 |

**Story**
As an HR user, I want every employee to have leave balances and a ledger, so that entitlements,
adjustments, and usage are accurate.

**Feature**
- Default annual balances for earned, sick, and casual on activation.
- Unpaid leave is balance-free.
- Ledger entries: entitlement, adjustment, usage, cancellation, reset.
- HR adjustment with a mandatory reason.
- Yearly reset on 1 January with no carryover; prior year remains viewable.

**Acceptance criteria**

- **AC-01** Activation creates balances from the configured default entitlements.
- **AC-02** Balances show entitlement, adjustments, used, and remaining, and the ledger sums to the balance.
- **AC-03** HR adjustments require a reason and are audit-logged.
- **AC-04** The yearly reset creates new balances and preserves the previous year.
- **AC-05** Unpaid leave has no balance and cannot be over-drawn.
- **AC-06** A balance cannot become negative through HR adjustment below used days.

**Test cases**

| ID | Type | Given | When | Then |
|---|---|---|---|---|
| TC-S13-01 | H | The employee activated in S12 has defaults earned 18, sick 10, casual 8 | Open her leave page | Three balances exist with full remaining |
| TC-S13-02 | H | HR adds +2 earned days with reason "policy correction" | Save | Remaining becomes 20; ledger shows +2 with reason and actor |
| TC-S13-03 | H | Priya has 2 approved earned days used | Open the ledger | Entitlement + adjustments − used = remaining |
| TC-S13-04 | E | Simulated date is 1 January of the next year | Run the reset | New-year balances equal defaults; prior-year ledger remains viewable |
| TC-S13-05 | N | HR tries to reduce earned balance below used days | Save | Validation error; balance unchanged |
| TC-S13-06 | E | Employee requests unpaid leave | Open balances | No unpaid balance row appears; request is still allowed |

Existing active bootstrap employees (including Priya) are backfilled with balances by the same
provisioning service used for new activations, so later stories can request leave for them.

---

## S14 — Leave request submission

| | |
|---|---|
| Epic | Leave |
| Priority | P0 |
| Depends on | S13 |
| Covers | LVE-03, LVE-04, LVE-09, LVE-14, BR-LVE-01, BR-LVE-02, BR-LVE-07 |

**Story**
As an employee, I want to request leave with dates and type, so that my manager can approve it and
payroll can account for unpaid days.

**Feature**
- Request form: type, start date, end date, reason, optional attachment.
- Working-day calculation (Monday–Friday, no holidays).
- Balance validation for earned, sick, and casual; no balance limit for unpaid.
- Overlap and employment-date validation.
- Pending status and email to the approver.
- Employee can cancel a pending request.

**Acceptance criteria**

- **AC-01** A valid request is created in `pending` status and routed per S15.
- **AC-02** The day count excludes weekends.
- **AC-03** Requests exceeding available balance are rejected for balanced types.
- **AC-04** Overlapping requests and dates outside employment are rejected.
- **AC-05** Unpaid leave is accepted without a balance and marked for payroll deduction.
- **AC-06** Cancelling a pending request closes it without changing the balance.

**Test cases**

| ID | Type | Given | When | Then |
|---|---|---|---|---|
| TC-S14-01 | H | Priya has 18 earned days | Request earned leave Monday–Tuesday (2 days) | Pending request created; 2 working days |
| TC-S14-02 | E | Request Friday–Monday | Submit | 2 working days counted; weekend excluded |
| TC-S14-03 | N | Priya already has approved leave 10–12 Nov | Request 11 Nov | Overlap rejected |
| TC-S14-04 | N | Priya has 1 earned day remaining | Request 3 earned days | Rejected for insufficient balance |
| TC-S14-05 | H | Priya requests unpaid leave for 3 days | Submit | Accepted; flagged for payroll deduction |
| TC-S14-06 | N | Priya's start date is 1 Dec | Request leave for 28 Nov | Rejected; outside employment |
| TC-S14-07 | H | Priya has a pending request | Cancel it | Status cancelled; balance unchanged |

---

## S15 — Hierarchy-based leave approval and team calendar

| | |
|---|---|
| Epic | Leave |
| Priority | P0 |
| Depends on | S14 |
| Covers | LVE-05 to LVE-10, LVE-13, R-09 to R-13, XC-04 |

**Story**
As a manager, I want to approve leave for my direct reports, and as an employee I want my own
request to go to my manager, so that approvals follow the hierarchy rather than a role.

**Feature**
- Routing to the direct manager; manager's own request to their manager; top-level request to HR.
- Approve/reject with optional comment and email notifications.
- Self-approval blocked.
- HR override with a mandatory reason.
- Approved leave reduces the balance; cancellation restores it.
- Team calendar for the manager's subtree.
- Pending requests re-routed when the manager changes.

**Acceptance criteria**

- **AC-01** A request routes to the requester's direct manager.
- **AC-02** A manager's request routes to their own manager; if none, to HR.
- **AC-03** Users cannot approve their own requests.
- **AC-04** Approval reduces the balance and rejection leaves it unchanged; both email the requester.
- **AC-05** HR can approve, reject, or cancel any request with a recorded reason.
- **AC-06** Cancelling approved leave restores the days.
- **AC-07** The team calendar shows approved leave for the manager's subtree only.
- **AC-08** Changing a manager re-routes that employee's pending requests.

**Test cases**

| ID | Type | Given | When | Then |
|---|---|---|---|---|
| TC-S15-01 | H | Priya's request is pending; Arjun is her manager | Arjun approves | Status approved; 2 earned days deducted; Priya gets email |
| TC-S15-02 | H | Pending request | Arjun rejects with comment | Status rejected; balance unchanged; comment visible to Priya |
| TC-S15-03 | H | Arjun requests leave; Meera is his manager | Submit | Approver is Meera, not Arjun |
| TC-S15-04 | E | Meera requests leave and has no manager | Submit | Approver is the HR team |
| TC-S15-05 | N | Arjun is the approver | Arjun tries to approve his own request via direct URL | Rejected; status unchanged |
| TC-S15-06 | H | Priya has a pending request | HR approves with reason "manager unavailable" | Approved; reason recorded; emails sent |
| TC-S15-07 | H | Priya has approved leave | Cancel the approved leave | Days return to balance; ledger records the return |
| TC-S15-08 | E | Priya has pending leave; her manager changes from Arjun to Meera | Change manager | Pending request now shows Meera as approver |
| TC-S15-09 | P | Priya's leave is approved | Sign in as Arjun, open team calendar | Priya's leave is visible; John (USA) is not |
| TC-S15-10 | H | Priya has a pending unpaid leave request for 2 days in the payroll month | HR approves the request | Status approved; the days are flagged as unpaid for the payroll run |

---

## S16 — Attendance CSV import

| | |
|---|---|
| Epic | Attendance |
| Priority | P0 |
| Depends on | S12 |
| Covers | ATT-01, ATT-02, ATT-03, NFR-02 |

**Story**
As an HR user, I want to import attendance from device CSV files, so that attendance no longer
lives in spreadsheets.

**Feature**
- CSV format: Employee ID, First In (timestamp), Last Out (timestamp).
- Upload with header validation, row validation, and import summary.
- Re-upload updates the same employee/date rather than duplicating.
- Records visible to the employee and their manager subtree.
- Only HR can import.

**Acceptance criteria**

- **AC-01** A valid CSV imports all rows and reports the count.
- **AC-02** Missing or malformed columns reject the file with a clear message.
- **AC-03** Unknown employee IDs and invalid timestamps are reported per row; valid rows import.
- **AC-04** Re-importing the same employee and date updates the record instead of creating a duplicate.
- **AC-05** Employees see their own attendance; managers see their subtree; HR sees all.
- **AC-06** Import is restricted to HR.

**Test cases**

| ID | Type | Given | When | Then |
|---|---|---|---|---|
| TC-S16-01 | H | `attendance_sample.csv` with 3 valid rows for Priya, Arjun, John | Upload | 3 records imported; summary shows 3 succeeded |
| TC-S16-02 | N | CSV header missing "Last Out" | Upload | File rejected with a header error; no rows imported |
| TC-S16-03 | E | Row for employee `EMP999` who does not exist | Upload | Row rejected with "unknown employee"; other rows import |
| TC-S16-04 | N | Row where Last Out is earlier than First In | Upload | Row rejected with a time-order error |
| TC-S16-05 | E | Same file uploaded again | Upload | Records update; total count does not grow |
| TC-S16-06 | P | Priya signed in | Upload a CSV | Access denied; data unchanged |
| TC-S16-07 | P | Arjun signed in | Open John's attendance (outside his subtree) | Access denied |

---

## S17 — Attendance exceptions and reconciliation

| | |
|---|---|
| Epic | Attendance |
| Priority | P0 |
| Depends on | S16, S15 |
| Covers | ATT-04 to ATT-09, BR-ATT-01 to BR-ATT-04 |

**Story**
As an HR user, I want attendance exceptions and a monthly reconciliation view, so that leave and
attendance conflicts are resolved before payroll.

**Feature**
- Exception detection: missing first-in or last-out, no attendance on a working day without approved leave, attendance on approved leave.
- HR correction with a reason; exception review/waive.
- Monthly reconciliation: approved leave, unpaid days, attendance days, open exceptions per employee.
- Export of reconciliation data.
- Manager visibility limited to subtree.

**Acceptance criteria**

- **AC-01** Exceptions are generated for the three defined conditions on working days.
- **AC-02** HR corrections update the record, are audit-logged, and resolve the related exception.
- **AC-03** Waived exceptions are excluded from the open count but retained.
- **AC-04** The reconciliation view shows correct leave and attendance totals per employee for the month.
- **AC-05** Reconciliation export matches the on-screen numbers and respects permissions.
- **AC-06** Managers see only their subtree's exceptions.

**Test cases**

| ID | Type | Given | When | Then |
|---|---|---|---|---|
| TC-S17-01 | H | Priya has attendance with no Last Out | Open exceptions | "Missing last out" exception appears for that date |
| TC-S17-02 | E | Priya has no attendance and no approved leave on a working day | Open exceptions | "No attendance, no leave" exception appears |
| TC-S17-03 | E | Priya has approved leave on a day with attendance | Open exceptions | "Attendance on leave" conflict appears |
| TC-S17-04 | H | Missing last-out exception exists | HR enters Last Out with reason "device error" | Record corrected; exception resolved; change audited |
| TC-S17-05 | H | An exception exists | HR waives it with a reason | Exception moves to waived; open count decreases |
| TC-S17-06 | H | Month has attendance, approved leave, and unpaid days | Open monthly reconciliation | Days and exception counts match the records |
| TC-S17-07 | H | Reconciliation visible | Export CSV | Export rows and totals match the screen |
| TC-S17-08 | P | Arjun signed in | Open reconciliation for John (USA) | Access denied; only his subtree is visible |

---

## S18 — Monthly payroll run

| | |
|---|---|
| Epic | Payroll |
| Priority | P0 |
| Depends on | S15, S17 |
| Covers | PAY-01 to PAY-05, PAY-09, PAY-11, BR-PAY-01 to BR-PAY-08 |

**Story**
As an HR user, I want to prepare a monthly payroll run from CTC, unpaid leave, and manual
adjustments, so that the payout amounts are complete and validated before export.

**Feature**
- Select a month and create a draft run for all `active`/`notice` employees.
- Monthly gross = sum of annual components ÷ 12.
- Automatic unpaid-leave deduction using working days in the month.
- Manual adjustments with descriptions.
- Blocking validation for missing bank name, account number, CTC, or components; warning for CTC/component mismatch.
- Review totals by employee, country, currency; no tax or other deductions.

**Acceptance criteria**

- **AC-01** The run includes `active` and `notice` employees and excludes `exited` employees.
- **AC-02** Monthly gross equals the sum of components divided by 12, rounded to two decimals.
- **AC-03** Unpaid leave days in the month produce the deduction `(monthly gross ÷ working days) × unpaid days`.
- **AC-04** Adjustments are added or subtracted with a description and appear in the total.
- **AC-05** Export-blocking data issues are listed and prevent approval; CTC mismatch is a warning.
- **AC-06** The run cannot be created or edited by non-HR users.
- **AC-07** No tax, statutory deduction, benefit, or payslip value is calculated.

**Test cases**

| ID | Type | Given | When | Then |
|---|---|---|---|---|
| TC-S18-01 | H | Active employees with CTC and components exist | Create a run for November 2026 | Draft run lists all active employees with monthly gross |
| TC-S18-02 | H | Priya's CTC is 1,200,000 (Basic 1,200,000) | Open her payroll line | Monthly gross is 100,000.00 |
| TC-S18-03 | H | Priya has 2 unpaid leave days in a month with 20 working days | Add to the run | Deduction is 10,000.00 (100,000 ÷ 20 × 2) |
| TC-S18-04 | H | HR adds a bonus adjustment of 5,000 | Save | Total = gross − unpaid deduction + 5,000; description shown |
| TC-S18-05 | N | Employee has no bank account number | Attempt to approve/export | Blocked; the employee is listed as missing bank details |
| TC-S18-06 | E | Components total 1,000,000 but CTC is 1,200,000 | Create run | Warning shown; HR must resolve before export |
| TC-S18-07 | H | Draft run exists | Filter/summarise by country and currency | Totals reconcile with employee lines; no conversion across currencies |
| TC-S18-08 | P | Arjun (manager) signed in | Create or edit a payroll run | Access denied |

---

## S19 — Payroll Excel export and history

| | |
|---|---|
|---|---|
| Epic | Payroll |
| Priority | P0 |
| Depends on | S18 |
| Covers | PAY-06 to PAY-08, PAY-10, BR-PAY-06 |

**Story**
As an HR user, I want to export the approved monthly payroll to Excel and re-download past runs, so
that Finance can pay employees from one file.

**Feature**
- Generate XLSX with the documented columns, including bank name, IFSC, account number, gross, unpaid deduction, adjustments, total, pay period.
- Generated runs are immutable; re-download returns the same content.
- Status: draft → generated → paid.
- Export and status changes are audit-logged.

**Acceptance criteria**

- **AC-01** Export is available only for a complete run with no blocking issues.
- **AC-02** The file contains every required column and one row per included employee.
- **AC-03** Amounts and bank details in the file match the review screen.
- **AC-04** After generation, the run is locked; edits are rejected.
- **AC-05** A generated run can be re-downloaded with identical content and marked paid.
- **AC-06** Export and paid status are recorded in the audit history.
- **AC-07** Only HR can export.

**Test cases**

| ID | Type | Given | When | Then |
|---|---|---|---|---|
| TC-S19-01 | H | Approved draft run | Export XLSX | File downloads and opens; headers match the specification |
| TC-S19-02 | H | Exported file | Compare Priya's row | Bank name, IFSC, account number, gross, deduction, adjustment, total, period are correct |
| TC-S19-03 | N | Export completed | Attempt to edit the run | Edit rejected; run is immutable |
| TC-S19-04 | H | Generated run exists | Re-download | Content identical (same amounts and rows) |
| TC-S19-05 | H | Generated run exists | Mark as paid with a date | Status becomes paid; date recorded |
| TC-S19-06 | H | Export performed | Open audit history | Export actor, timestamp, and paid status are listed |
| TC-S19-07 | P | Priya signed in | Request the payroll export URL | Access denied |

---

## S20 — Offboarding and access deactivation

| | |
|---|---|
| Epic | Offboarding |
| Priority | P0 |
| Depends on | S12, S19 |
| Covers | OFF-01 to OFF-08, BR-OFF-01 to BR-OFF-03 |

**Story**
As an HR user, I want to offboard an employee with a checklist and automatic access removal, so
that the exit is clean and final pay is included.

**Feature**
- Initiate offboarding with type, reason, notice period, and last working day; status becomes `notice`.
- Checklist: handover, asset return, knowledge transfer, external access confirmation.
- Automatic app login deactivation after the last working day, or immediate deactivation.
- Final pay adjustment (final salary, leave payout, other) for the next run.
- Exit notes visible to HR only; rehire eligibility flag; record retained.

**Acceptance criteria**

- **AC-01** Offboarding sets status `notice` and stores the last working day.
- **AC-02** Checklist tasks are created and visible to HR and the manager.
- **AC-03** Login is blocked after the last working day; HR can deactivate immediately.
- **AC-04** Final pay adjustments appear in the next payroll run.
- **AC-05** Exit notes are HR-only and the rehire flag is stored.
- **AC-06** An exited employee is excluded from subsequent payroll runs and cannot request leave.
- **AC-07** The employee record remains visible to HR with history intact.

**Test cases**

| ID | Type | Given | When | Then |
|---|---|---|---|---|
| TC-S20-01 | H | Emily is active | Initiate offboarding with last working day 30 Nov | Status `notice`; date stored; checklist created |
| TC-S20-02 | E | Last working day 30 Nov; simulated date 1 Dec | Employee tries to sign in | Login blocked; session cannot be established |
| TC-S20-03 | H | Offboarding in progress | HR deactivates immediately | Login blocked at once; checklist records the action |
| TC-S20-04 | H | Final pay adjustment of 50,000 entered | Create the next payroll run | Emily appears with the final-pay line |
| TC-S20-05 | H | Exit notes entered | Sign in as Emily's manager (Carol) | Notes are not visible; HR can see them |
| TC-S20-06 | H | Rehire flag set to "eligible" | View the employee record | Flag is displayed to HR |
| TC-S20-07 | E | Emily is exited | Run payroll for the following month | Emily is excluded automatically |
| TC-S20-08 | P | Emily signed in before exit | Request leave after the last working day | Request rejected |

---

## S21 — Reporting dashboards and exports

| | |
|---|---|
| Epic | Reporting |
| Priority | P0 |
| Depends on | S20 |
| Covers | RPT-01 to RPT-12, BR-RPT-01 to BR-RPT-03 |

**Story**
As an HR user or manager, I want standard reports and dashboards, so that I can answer headcount,
attrition, leave, attendance, payroll, and hiring questions without Excel.

**Feature**
- HR dashboard: headcount, joiners/leavers, pending approvals, payroll status, attendance exceptions.
- Reports: headcount by country/department/manager/status, joiners and leavers, attrition, leave balances and usage, attendance exceptions, payroll totals by month/country/currency, recruitment pipeline.
- Manager dashboard scoped to subtree.
- Filters and CSV/XLSX export; permission-safe.
- No salary or bank data for managers or candidates.

**Acceptance criteria**

- **AC-01** Headcount reconciles with the employee list for the same filters.
- **AC-02** Joiners/leavers show the correct dates and count.
- **AC-03** Attrition equals leavers ÷ average of opening and closing headcount, with the formula visible.
- **AC-04** Leave and attendance reports reconcile with their source records.
- **AC-05** Payroll totals reconcile with generated runs and are grouped by currency without conversion.
- **AC-06** Managers see only their subtree; candidates cannot access reports.
- **AC-07** Exports match the on-screen filtered results and are audit-logged.
- **AC-08** Salary, CTC, and bank details never appear in manager or candidate output.

**Test cases**

| ID | Type | Given | When | Then |
|---|---|---|---|---|
| TC-S21-01 | H | Employees across three countries | Filter headcount by country | Counts match the filtered employee list |
| TC-S21-02 | H | One joiner and one leaver in November | Open joiners/leavers | Lists show both with correct dates |
| TC-S21-03 | H | Opening headcount 20, closing 18, 4 leavers | Open attrition | Value is 4 ÷ 19 = 21.05%, formula visible |
| TC-S21-04 | H | Leave and attendance data exist | Open leave and attendance reports | Totals match balances, requests, and exceptions |
| TC-S21-05 | H | Payroll runs exist | Open payroll totals | Totals match runs, grouped by currency |
| TC-S21-06 | H | Recruitment data exists | Open pipeline report | Counts match openings and applications |
| TC-S21-07 | P | Arjun (manager) signed in | Open HR dashboard and a report for John (USA) | HR dashboard denied; only his subtree report is visible |
| TC-S21-08 | P | Nisha (candidate) signed in | Open any report URL | Access denied |
| TC-S21-09 | H | Headcount report filtered to India | Export XLSX | File rows and totals match the filtered list |
| TC-S21-10 | P | Arjun signed in | Export a report | No salary, CTC, or bank columns are present |

---

## S22 — Demo seed data and scale verification

| | |
|---|---|
| Epic | Demo readiness |
| Priority | P0 |
| Depends on | S21 |
| Covers | NFR-16, NFR-17, NFR-02, G1, G6 |

**Story**
As a demo owner, I want a repeatable seed with 10,000 employees, 100 candidates, and two months of
attendance, so that the product can be demonstrated and performance-tested at realistic scale.

**Feature**
- Faker-based seed script with a default size of 10,000 employees and 100 candidates.
- Multi-level hierarchy across India, USA, and Canada; country-appropriate currencies.
- 100 candidates with applications in different stages (Applied, Screening, Interview, Offer, Hired, Rejected).
- Two months of attendance for active employees.
- Idempotent re-run (no duplicates), clear prefixes for seeded records, and a runtime target.
- Sample login accounts for demo roles.

**Acceptance criteria**

- **AC-01** A single command seeds 10,000 employees, 100 candidates, and attendance for the last two months.
- **AC-02** Employees span India, USA, and Canada with the correct currencies and a hierarchy at least three levels deep.
- **AC-03** Candidates have applications distributed across all pipeline stages.
- **AC-04** Attendance covers working days for the last two months for active employees.
- **AC-05** Re-running the seed does not duplicate records.
- **AC-06** The full seed completes within 15 minutes.
- **AC-07** Sample HR, manager, employee, and candidate accounts can sign in.
- **AC-08** Headcount reporting reflects the seeded population after the run.

**Test cases**

| ID | Type | Given | When | Then |
|---|---|---|---|---|
| TC-S22-01 | H | Clean development database | Run the seed command | Command completes successfully; summary reports 10,000 employees and 100 candidates |
| TC-S22-02 | H | Seed completed | Count employees by country | All three countries present; INR, USD, CAD assigned correctly |
| TC-S22-03 | H | Seed completed | Inspect hierarchy | At least three levels exist; no cycles; every manager is an employee |
| TC-S22-04 | H | Seed completed | Open recruitment pipeline | Applications exist in every stage |
| TC-S22-05 | H | Seed completed | Check attendance coverage | Active employees have attendance for working days in the last two months |
| TC-S22-06 | E | Seed already run | Run the seed again | No duplicate employee IDs, candidates, or attendance rows; counts unchanged |
| TC-S22-07 | PF | Clean database | Time the seed run | Completes in under 15 minutes |
| TC-S22-08 | H | Seed completed | Sign in with each sample account | HR, manager, employee, and candidate land on their correct dashboards |
| TC-S22-09 | H | Seed completed | Open headcount report | Reported total matches 10,000 (plus non-seed demo records) |

---

## End-to-end acceptance story

After S22 passes, run one continuous scenario:

1. Nisha (candidate) registers, signs in, and applies to the open Software Engineer role.
2. HR moves the application through Screening and Interview, records an interview, and creates an offer.
3. HR hires Nisha and converts her to an employee; the employee record references Nisha's candidate record.
4. HR completes onboarding, sends the invite, and activates the employee.
5. Nisha requests earned leave; Arjun approves; the balance decreases.
6. HR imports attendance for the month, including a conflict with Nisha's leave, and resolves it.
7. HR creates the monthly payroll run and exports the Excel payout file; Nisha's row is present with bank details.
8. HR offboards Nisha with a last working day and a final-pay adjustment; her login stops working.
9. HR opens the dashboard and confirms headcount, attrition, leave, attendance, and payroll figures.
