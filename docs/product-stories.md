# HR Demo — Product Stories and Test Cases

| Field | Value |
|---|---|
| Version | 1.1 |
| Date | 2026-10-27 |
| Source | `docs/requirements.md` v0.4 |
| Status | Built through S11c; S12–S19 moved to future-plans.md |

## How to use this document

- Stories are numbered **S01–S19** and must be built and tested **in order**. Each story assumes every earlier story is complete and its tests pass.
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
| S05 | Employee self-service and directory | People | S04 |
| S06 | Leave Excel upload (overnight) | Leave | S04, S05 |
| S07 | ~~Attendance CSV upload~~ (cut) | — | — |
| S08 | Monthly payroll run | Payroll | S06 |
| S09 | Payroll Excel export and history | Payroll | S08 |
| S10 | Reporting dashboards and exports | Reporting | S08, S09 |
| S11 | Demo seed data and scale verification | Demo readiness | S10 |
| S11a | Organisation tree view | People | S04, S11 |
| S11b | UI revamp | Demo readiness | S11a |
| S11c | NL-to-SQL assistant | Insights | S10, S11b |
| S12 | Candidate registration, login, and profile (future plan) | Hiring | S01 |
| S13 | Job openings (future plan) | Hiring | S12 |
| S14 | Job applications (future plan) | Hiring | S13 |
| S15 | Recruitment pipeline, interviews, and offers (future plan) | Hiring | S14 |
| S16 | Convert a hired candidate to an employee (future plan) | Hiring | S15, S03, S04 |
| S17 | Onboarding checklist, invite, and activation (future plan) | Onboarding | S16 |
| S18 | Offboarding and access deactivation (future plan) | Offboarding | S17, S09 |
| S19 | Employee change history (deferred from S05) (future plan) | People | S18 |

## Test accounts and fixtures used throughout

| Account | Role | Notes |
|---|---|---|
| `hr@demo.test` / `Demo@1234` | HR | Bootstrap account, created in S01 |
| `meera@demo.test` | Manager (top level, India) | No manager; leave routes to HR |
| `arjun@demo.test` | Manager (India, reports to Meera) | Has Priya as a direct report |
| `priya@demo.test` | Employee (India, reports to Arjun) | Used for leave tests |
| `robert@demo.test` | Manager (USA) | One direct report: John |
| `john@demo.test` | Employee (USA, reports to Robert) | Used for payroll tests |
| `carol@demo.test` | Manager (Canada) | One direct report: Emily |
| `emily@demo.test` | Employee (Canada, reports to Carol) | Used for offboarding tests |
| `nisha@example.test` / `Candidate@123` | Candidate | Registered in S12 |

Fixtures: `leave_sample.xlsx`, `leave_invalid.xlsx`, `resume.pdf`, `offer_letter.pdf`. The leave Excel format was confirmed in S06.

All demo accounts use `Demo@1234` unless noted. The bootstrap creates the authentication user and a minimal employee record (name, country, department, status, sample CTC/components, and bank details) so authentication and later stories have stable data. Stories S03–S06 add new records on top of it.

---

## S01 — Sign-in and role-based access

| | |
|---|---|
| Epic | Foundation |
| Priority | P0 |
| Depends on | — |
| Covers | XC-03, NFR-04, NFR-05 |

**Story**
As an HR user or employee, I want to sign in with my credentials and land on the correct dashboard, so that I only see the data my role allows.

**Feature**
- Email and password authentication for HR and employees (candidates added in S12).
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
As an HR user, I want to maintain the fixed country list, departments, and leave types, so that employee and leave records use consistent values.

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
As an HR user, I want to create an employee with personal, job, compensation, and bank details, so that the employee has one authoritative record.

**Feature**
- Manual employee creation with required fields: employee ID, first/last name, work email, country, department, job title, start date, at least one compensation component, bank name, account number, status.
- Country drives currency automatically.
- Unique employee ID and work email.
- Annual CTC is derived from the sum of the compensation components and is not entered independently.
- Employee-level access to their own record; HR-only editing of compensation and bank data.

**Acceptance criteria**

- **AC-01** An employee can be created with all required fields and appears in the employee list.
- **AC-02** Currency is set automatically from country and cannot be edited independently.
- **AC-03** Duplicate employee ID or work email is rejected with a field-level error.
- **AC-04** Annual CTC is calculated from the sum of the stored compensation components and cannot be supplied as an independent value.
- **AC-05** The employee can view their own profile, including CTC and bank details, but cannot edit them.
- **AC-06** An employee has a status of `onboarding` or `active` and a start date.

**Test cases**

| ID | Type | Given | When | Then |
|---|---|---|---|---|
| TC-S03-01 | H | Signed in as HR; Engineering and India exist | Create employee EMP101, Ravi Kumar, `ravi@demo.test`, India, with components Basic 1,000,000 and Allowance 200,000 | Employee is saved; annual CTC is 1,200,000; currency is INR; list shows Ravi |
| TC-S03-02 | H | Signed in as HR | Create a Canadian employee | Currency is CAD automatically; no currency selector is shown |
| TC-S03-03 | N | Employee EMP101 exists | Create another employee with ID EMP101 | Validation error on employee ID; nothing is saved |
| TC-S03-04 | N | Employee `ravi@demo.test` exists | Create an employee with the same work email | Validation error on email |
| TC-S03-05 | E | Signed in as HR | Enter components Basic 1,000,000.50 and Allowance 199,999.50 | Annual CTC is derived as 1,200,000.00; no separate CTC field is accepted |
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
As an HR user, I want to assign managers and maintain a hierarchy, so that teams, visibility, and leave approvals follow the reporting line.

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

## S05 — Employee self-service and directory

| | |
|---|---|
| Epic | People |
| Priority | P0 |
| Depends on | S04 |
| Covers | EMP-05, EMP-06, EMP-11, XC-07 |

**Story**
As an employee, I want to maintain my contact details and find colleagues in the directory, so that records stay accurate.

**Feature**
- Employee self-service for phone, personal email, address, and emergency contact.
- Read-only employee ID, work email, job, compensation, and bank data.
- Directory with search and filters by country, department, manager, and status.
- Permission-aware directory results.

**Acceptance criteria**

- **AC-01** Self-service changes save immediately and are visible to HR.
- **AC-02** Employee ID, work email, compensation, bank, and hierarchy fields cannot be edited by the employee.
- **AC-03** Directory filters return exactly the matching employees and respect the viewer's scope.
- **AC-04** Moved to S19 (employee change history).
- **AC-05** Salary, CTC, and bank details never appear in directory cards, search results, or manager views.
- **AC-06** A manager's directory view is limited to their subtree.

**Test cases**

| ID | Type | Given | When | Then |
|---|---|---|---|---|
| TC-S05-01 | H | Signed in as Priya | Change phone to `+91-98765-43210` | Value saves and is visible to HR |
| TC-S05-02 | N | Signed in as Priya | Try to change work email | Field is read-only and the request is rejected |
| TC-S05-03 | H | Employees exist in India, USA, Canada | Filter directory by country = USA | Only USA employees are listed |
| TC-S05-04 | H | Directory has 20+ employees | Search by partial name | Matching employees are returned, scoped to the viewer |
| TC-S05-05 | — | Moved to S19 as TC-S19-01 | — | — |
| TC-S05-06 | P | Signed in as Arjun (manager) | Open directory | Only Arjun's subtree is listed |
| TC-S05-07 | P | Signed in as Priya | Search directory | Salary and bank columns are absent; other employees are limited to directory fields |

---

## S06 — Leave Excel upload (overnight)

| | |
|---|---|
| Epic | Leave |
| Priority | P0 |
| Depends on | S04, S05 |
| Covers | LVE-01 to LVE-14, BR-LVE-01 to BR-LVE-07 |

**Story**
As an HR user, I want to upload a leave Excel file overnight so that balances, requests, and approvals are processed without an interactive leave UI.

**Feature**
- Overnight Excel (.xlsx, first sheet, max 5 MB) of approved leave, one row per employee on leave
  for one day, with header row `employee_id | leave_date | leave_type | reason` (`leave_date` as
  an Excel date or `YYYY-MM-DD` text; `leave_type` is earned, sick, casual, or unpaid; `reason`
  optional).
- Upload is stored and processed by a background job; HR polls the import for its summary.
- Header validation, row validation, and import summary.
- Unknown employee IDs, invalid or weekend dates, dates before the start date, and insufficient
  balances reported per row.
- Every row is approved leave and reduces the balance; entitlements are granted when an employee
  is created (existing employees backfilled once).
- Unpaid leave has no balance and is flagged for payroll deduction.
- Working-day calculation (Monday–Friday, no holidays).
- Only HR can import.
- Re-upload updates existing leave records rather than duplicating.

**Acceptance criteria**

- **AC-01** A valid leave Excel file imports all rows and reports the count.
- **AC-02** Missing or malformed columns reject the file with a clear message.
- **AC-03** Unknown employee IDs, invalid or weekend dates, dates before the start date, and insufficient balances are reported per row; valid rows import.
- **AC-04** Imported earned/sick/casual leave reduces the remaining balance by one day per row.
- **AC-05** Unpaid leave has no balance, cannot be over-drawn, and is flagged for payroll deduction.
- **AC-06** Re-uploading the same employee/date updates the record instead of creating a duplicate.
- **AC-07** Leave records respect the viewer's scope: employees see their own, managers see their subtree, HR sees all.
- **AC-08** Only HR can access leave import.

**Test cases**

| ID | Type | Given | When | Then |
|---|---|---|---|---|
| TC-S06-01 | H | `leave_sample.xlsx` with 5 valid rows | Upload | 5 records imported; summary shows 5 succeeded |
| TC-S06-02 | N | Sheet header missing "leave_type" | Upload | File rejected with a header error; no rows imported |
| TC-S06-03 | E | Row for employee `EMP999` who does not exist | Upload | Row rejected with "unknown employee"; other rows import |
| TC-S06-04 | N | Row with a Saturday `leave_date` | Upload | Row rejected as not a working day |
| TC-S06-05 | N | Priya has 0 earned days remaining | Upload an earned row for her | Row rejected for insufficient balance |
| TC-S06-06 | H | Unpaid row for Priya | Upload | Accepted; no balance change; flagged for payroll deduction |
| TC-S06-07 | E | Same file uploaded again | Upload | Records update; total count does not grow |
| TC-S06-08 | P | Priya signed in | Upload an Excel file | Access denied; data unchanged |
| TC-S06-09 | P | Arjun signed in | Open John's leave record (outside his subtree) | Access denied |

---

## S07 — Attendance CSV upload (cut)

Cut from scope on 2026-10-27. Leave records from S06 are the only source for absence; attendance
import, exception detection, and reconciliation are not built. The ID is kept so later story
numbers stay stable.

---

## S08 — Monthly payroll run

| | |
|---|---|
| Epic | Payroll |
| Priority | P0 |
| Depends on | S06 |
| Covers | PAY-01 to PAY-05, PAY-09, PAY-11, BR-PAY-01 to BR-PAY-08 |

**Story**
As an HR user, I want to prepare a monthly payroll run from CTC and unpaid leave (from the leave Excel uploads), so that the payout amounts are complete and validated before export.

**Feature**
- Select a month and create a draft run for `active` employees who started on or before the month end (`notice` added in S18). One run per month.
- The draft stores its lines; HR can recalculate a draft after new leave uploads.
- Monthly gross = sum of annual components ÷ 12.
- Automatic unpaid-leave deduction using working days in the month (from uploaded leave records).
- Manual adjustments are deferred (not in S08); total = gross − unpaid deduction.
- Blocking validation for missing bank name, account number, or components; annual CTC is derived from the component sum.
- Review totals by employee, country, currency; no tax or other deductions.
- Only HR can create, edit, or export a payroll run.

**Acceptance criteria**

- **AC-01** The run includes `active` employees who started on or before the month end; `notice`/`exited` handling arrives with S18.
- **AC-02** Monthly gross equals the sum of components divided by 12, rounded to two decimals.
- **AC-03** Unpaid leave days in the month produce the deduction `(monthly gross ÷ working days) × unpaid days`.
- **AC-04** Deferred: manual adjustments are not part of S08.
- **AC-05** Export-blocking data issues are listed on the draft run and will block generation/export in S09.
- **AC-06** The run cannot be created or edited by non-HR users.
- **AC-07** No tax, statutory deduction, benefit, or payslip value is calculated.

**Test cases**

| ID | Type | Given | When | Then |
|---|---|---|---|---|
| TC-S08-01 | H | Active employees with CTC and components exist | Create a run for November 2026 | Draft run lists all active employees with monthly gross |
| TC-S08-02 | H | Priya's CTC is 1,200,000 (Basic 1,200,000) | Open her payroll line | Monthly gross is 100,000.00 |
| TC-S08-03 | H | Priya has 2 unpaid leave days in a month with 20 working days | Add to the run | Deduction is 10,000.00 (100,000 ÷ 20 × 2) |
| TC-S08-04 | — | Deferred with manual adjustments | — | — |
| TC-S08-05 | N | Employee has no bank account number | Create the run | The employee is listed as a blocking issue (missing bank details) |
| TC-S08-06 | E | Employee has no compensation components | Create the run | The employee is listed as a blocking issue (missing components); CTC mismatch cannot occur because CTC is derived (BR-PAY-08) |
| TC-S08-07 | H | Draft run exists | Filter/summarise by country and currency | Totals reconcile with employee lines; no conversion across currencies |
| TC-S08-08 | P | Arjun (manager) signed in | Create, view, or recalculate a payroll run | Access denied |

---

## S09 — Payroll Excel export and history

| | |
|---|---|
| Epic | Payroll |
| Priority | P0 |
| Depends on | S08 |
| Covers | PAY-06 to PAY-08, PAY-10, BR-PAY-06 |

**Story**
As an HR user, I want to export the approved monthly payroll to Excel and re-download past runs, so that Finance can pay employees from one file.

**Feature**
- Generate a draft run whose calculation is complete and has no blocking issues; employee and bank details are frozen onto its lines.
- Export XLSX with the documented columns, including bank name, IFSC, account number, gross, unpaid deduction, total, pay period (no adjustments column; adjustments are deferred).
- Generated runs are immutable; re-download returns the same content.
- Status: draft → generated → paid (paid with a date, not in the future).
- Audit logging of export and status changes is deferred.
- Only HR can export.

**Acceptance criteria**

- **AC-01** Export is available only for a complete run with no blocking issues.
- **AC-02** The file contains every required column and one row per included employee.
- **AC-03** Amounts and bank details in the file match the review screen.
- **AC-04** After generation, the run is locked; edits are rejected.
- **AC-05** A generated run can be re-downloaded with identical content and marked paid.
- **AC-06** Deferred: audit history for export and paid status will be added later.
- **AC-07** Only HR can export.

**Test cases**

| ID | Type | Given | When | Then |
|---|---|---|---|---|
| TC-S09-01 | H | Approved draft run | Export XLSX | File downloads and opens; headers match the specification |
| TC-S09-02 | H | Exported file | Compare Priya's row | Bank name, IFSC, account number, gross, deduction, total, period are correct |
| TC-S09-03 | N | Export completed | Attempt to edit the run | Edit rejected; run is immutable |
| TC-S09-04 | H | Generated run exists | Re-download | Content identical (same amounts and rows) |
| TC-S09-05 | H | Generated run exists | Mark as paid with a date | Status becomes paid; date recorded |
| TC-S09-06 | — | Deferred with audit history | — | — |
| TC-S09-07 | P | Priya signed in | Request the payroll export URL | Access denied |

---

## S10 — Reporting dashboards and exports

| | |
|---|---|
| Epic | Reporting |
| Priority | P0 |
| Depends on | S08, S09 |
| Covers | RPT-01 to RPT-12, BR-RPT-01 to BR-RPT-03 |

**Scope in this build** (agreed 2026-10-27)
- In: headcount, joiners, leave report (entitlement, used, remaining, unpaid days), payroll totals from generated/paid runs, XLSX export, HR and manager dashboard tiles for those numbers.
- Moved: leavers and attrition (AC-02 leavers, AC-03, TC-S10-02 leaver, TC-S10-03) to S18; pipeline report (TC-S10-06) to the end of S15; candidate denial (TC-S10-08) is verified once candidates exist (S12).
- Deferred: pending approvals, headcount trend snapshots (RPT-11), CSV export, export audit logging (AC-07 logging part). Attendance is cut with S07.
- Managers see headcount, joiners and leave for their subtree; payroll totals and the HR dashboard are HR only.

**Story**
As an HR user or manager, I want standard reports and dashboards, so that I can answer headcount, attrition, leave, payroll, and hiring questions without Excel.

**Feature**
- HR dashboard: headcount, joiners/leavers, pending approvals, payroll status.
- Reports: headcount by country/department/manager/status, joiners and leavers, attrition, leave balances and usage, payroll totals by month/country/currency, recruitment pipeline.
- Manager dashboard scoped to subtree.
- Filters and CSV/XLSX export; permission-safe.
- No salary or bank data for managers or candidates.

**Acceptance criteria**

- **AC-01** Headcount reconciles with the employee list for the same filters.
- **AC-02** Joiners/leavers show the correct dates and count.
- **AC-03** Attrition equals leavers ÷ average of opening and closing headcount, with the formula visible.
- **AC-04** Leave reports reconcile with their source records.
- **AC-05** Payroll totals reconcile with generated runs and are grouped by currency without conversion.
- **AC-06** Managers see only their subtree; candidates cannot access reports.
- **AC-07** Exports match the on-screen filtered results and are audit-logged.
- **AC-08** Salary, CTC, and bank details never appear in manager or candidate output.

**Test cases**

| ID | Type | Given | When | Then |
|---|---|---|---|---|
| TC-S10-01 | H | Employees across three countries | Filter headcount by country | Counts match the filtered employee list |
| TC-S10-02 | H | One joiner and one leaver in November | Open joiners/leavers | Lists show both with correct dates |
| TC-S10-03 | H | Opening headcount 20, closing 18, 4 leavers | Open attrition | Value is 4 ÷ 19 = 21.05%, formula visible |
| TC-S10-04 | H | Leave data exists | Open leave reports | Totals match balances and leave records |
| TC-S10-05 | H | Payroll runs exist | Open payroll totals | Totals match runs, grouped by currency |
| TC-S10-06 | H | Recruitment data exists | Open pipeline report | Counts match openings and applications |
| TC-S10-07 | P | Arjun (manager) signed in | Open HR dashboard and a report for John (USA) | HR dashboard denied; only his subtree report is visible |
| TC-S10-08 | P | Nisha (candidate) signed in | Open any report URL | Access denied |
| TC-S10-09 | H | Headcount report filtered to India | Export XLSX | File rows and totals match the filtered list |
| TC-S10-10 | P | Arjun signed in | Export a report | No salary, CTC, or bank columns are present |

---

## S11 — Demo seed data and scale verification

| | |
|---|---|
| Epic | Demo readiness |
| Priority | P0 |
| Depends on | S10 |
| Covers | NFR-16, NFR-17, NFR-02, G1, G6 |

**Scope in this build** (agreed 2026-10-27)
- Employees load through the EMP-02 employee Excel import: one sheet with employee, bank, `Basic`/`HRA`/`Special Allowance` and `manager_employee_id` columns; pass 1 creates employees, users (default password from credentials), compensation and entitlements; pass 2 maps managers. Existing rows are rejected; manager errors carry a warning to use the update import.
- Update import (same workbook) appends compensation on an optional per-row `effective_date` and sets or changes managers; other columns are ignored.
- `demo:employee_workbook[10000]` generates the demo workbook (demo accounts EMP101–EMP107, `SEED` prefixes); `demo:seed_leave` seeds two months of leave.
- Moved: candidates and applications (AC-03, TC-S11-04, candidate account in AC-07) to the end of S15. No preview step.

**Story**
As a demo owner, I want a repeatable seed with 10,000 employees, 100 candidates, and two months of leave, so that the product can be demonstrated and performance-tested at realistic scale.

**Feature**
- Faker-based seed script with a default size of 10,000 employees and 100 candidates.
- Multi-level hierarchy across India, USA, and Canada; country-appropriate currencies.
- 100 candidates with applications in different stages (Applied, Screening, Interview, Offer, Hired, Rejected).
- Two months of leave records for a sample of active employees.
- Idempotent re-run (no duplicates), clear prefixes for seeded records, and a runtime target.
- Sample login accounts for demo roles.

**Acceptance criteria**

- **AC-01** A single command seeds 10,000 employees, 100 candidates, and leave records for the last two months.
- **AC-02** Employees span India, USA, and Canada with the correct currencies and a hierarchy at least three levels deep.
- **AC-03** Candidates have applications distributed across all pipeline stages.
- **AC-04** Leave records cover the last two months and respect balances.
- **AC-05** Re-running the seed does not duplicate records.
- **AC-06** The full seed completes within 15 minutes.
- **AC-07** Sample HR, manager, employee, and candidate accounts can sign in.
- **AC-08** Headcount reporting reflects the seeded population after the run.

**Test cases**

| ID | Type | Given | When | Then |
|---|---|---|---|---|
| TC-S11-01 | H | Clean development database | Run the seed command | Command completes successfully; summary reports 10,000 employees and 100 candidates |
| TC-S11-02 | H | Seed completed | Count employees by country | All three countries present; INR, USD, CAD assigned correctly |
| TC-S11-03 | H | Seed completed | Inspect hierarchy | At least three levels exist; no cycles; every manager is an employee |
| TC-S11-04 | H | Seed completed | Open recruitment pipeline | Applications exist in every stage |
| TC-S11-05 | H | Seed completed | Check leave coverage | Leave records exist for the last two months; no balance is negative |
| TC-S11-06 | E | Seed already run | Run the seed again | No duplicate employee IDs, candidates, or leave records; counts unchanged |
| TC-S11-07 | PF | Clean database | Time the seed run | Completes in under 15 minutes |
| TC-S11-08 | H | Seed completed | Sign in with each sample account | HR, manager, employee, and candidate land on their correct dashboards |
| TC-S11-09 | H | Seed completed | Open headcount report | Reported total matches 10,000 (plus non-seed demo records) |

---

## S11a — Organisation tree view

| | |
|---|---|
| Epic | People |
| Priority | P1 |
| Depends on | S04, S11 |
| Covers | R-06 (subtree visibility), G2 (working reporting hierarchy) |

**Story**
As an HR user or manager, I want to explore the reporting hierarchy as a collapsible tree and jump to any employee, so that I can see who reports to whom at 10,000-employee scale.

**Feature**
- Collapsible, keyboard-navigable tree (ReUI tree on headless-tree, shadcn style; replaced the earlier React Flow canvas on 2026-10-27); one row per employee with initials, name, employee ID, job title, and department; the name links to the profile; employees with reports can be expanded.
- Lazy loading: the tree starts at the top level (HR: employees without a manager; manager: themselves) and loads a node's direct reports when it is expanded.
- Focus: search by name or employee ID, or open "View in org chart" from a profile (`/org-chart?focus=<id>`); the manager chain to the top is expanded, the employee is centred and highlighted, and their direct reports are shown.
- Subtree: "Show only this subtree" (`/org-chart?root=<id>`) starts the tree at that employee; "Show full tree" returns.
- HR sees everyone; a manager sees only their subtree; other employees cannot open the tree. No salary, CTC, or bank data.

**Acceptance criteria**

- **AC-01** HR opens the tree at the employees without a manager; a manager opens it at themselves.
- **AC-02** Expanding a card loads only that employee's direct reports, each with their direct-report count.
- **AC-03** Focusing an employee expands their manager chain within the viewer's scope, highlights them, and shows their direct reports.
- **AC-04** Rooting the tree at an employee shows only that employee and their subtree.
- **AC-05** A manager cannot load, focus, or root on anyone outside their subtree; a non-manager employee is denied.
- **AC-06** Cards never show salary, CTC, or bank details.
- **AC-07** Expanding a node with many reports and loading a focus path use a bounded number of queries (no N+1).

**Test cases**

| ID | Type | Given | When | Then |
|---|---|---|---|---|
| TC-S11a-01 | H | Seeded hierarchy | HR opens the org chart | Top-level cards (Meera, Robert, Carol, and others without a manager) appear with report counts |
| TC-S11a-02 | H | Meera has direct reports | Expand Meera | Arjun and Meera's other direct reports load beneath her |
| TC-S11a-03 | H | Priya reports to Arjun, Arjun to Meera | Search "EMP101" | Meera and Arjun are expanded; Priya is highlighted |
| TC-S11a-04 | H | Focused on Arjun | Choose "Show only this subtree" | Only Arjun and his subtree are shown; "Show full tree" restores the full view |
| TC-S11a-05 | P | Arjun (manager) signed in | Request Robert's reports or focus on John | Access denied / not found |
| TC-S11a-06 | P | Priya (no reports) signed in | Open the org chart | Access denied |
| TC-S11a-07 | PF | 10,000 employees | Expand a manager with 5 reports; focus a level-6 employee | Constant query count per request; focus completes in a few requests |

---

## S11b — UI revamp

| | |
|---|---|
| Epic | Demo readiness |
| Priority | P1 |
| Depends on | S11a |
| Covers | Frontend look and navigation; dashboard trends (RPT-08, RPT-09 partial) |

**Story**
As any user, I want a consistent, modern interface with clear navigation and an informative dashboard, so that the product is pleasant to demo and use.

**Scope (agreed 2026-10-27/28)**
- shadcn sidebar app shell with role-filtered sections; indigo theme on Geist; light mode only.
- Dashboard: greeting, stat cards (onboarding tile removed), quick actions by role, and trend charts (headcount derived from start dates, joiners, leave days by type, payroll per currency for HR) from `GET /api/v1/reports/trends`, drawn with the shadcn chart component (Recharts).
- Every list and detail page on the shared page header, cards, tables, and status badges; Settings redesigned; onboarding removed from the headcount report screen and export.
- No behaviour change apart from the trends endpoint and the headcount export columns.

---

## S11c — NL-to-SQL assistant

| | |
|---|---|
| Epic | Insights |
| Priority | P1 |
| Depends on | S10, S11b |
| Covers | Self-service questions over HR data within each user's visibility |

**Story**
As any signed-in user, I want to ask a question in plain English and get a result table, so that I can answer ad-hoc questions without building a report, while seeing only data I am allowed to see.

**Feature**
- The question is turned into SQL by a configurable LLM provider (OpenRouter first; template-pattern provider classes allow switching).
- The SQL may only read per-request **scoped virtual relations** built from the existing Pundit scopes: HR sees all employees, departments, leave, compensation, and payroll lines; a manager sees themselves and their subtree without salary, CTC, or bank columns; an employee sees only their own records.
- Generated SQL is parsed with `pg_query` and rejected unless it is a single `SELECT` over the virtual relations using allowlisted functions; it runs read-only with a 3-second timeout and at most 200 rows.
- Cost controls: SQL cache per question and access tier, 5-minute result cache, per-user rate limit and daily token budget.
- The generated SQL is never shown to users; every request is recorded in an append-only audit table.

**Acceptance criteria**

- **AC-01** A valid question returns columns and rows (at most 200, flagged when truncated).
- **AC-02** Results never include rows or columns outside the asker's visibility, whatever SQL is generated.
- **AC-03** Non-SELECT statements, multiple statements, system catalogs, unknown relations, schema-qualified names, and non-allowlisted functions are rejected and never executed.
- **AC-04** Execution cannot modify data and stops after 3 seconds.
- **AC-05** A repeated question within an access tier does not call the model again.
- **AC-06** Rate limit and daily budget breaches return a clear error.
- **AC-07** Every request is audited (question, SQL, status, row count, duration, tokens).
- **AC-08** The provider and model are configurable without code changes; the API key comes from credentials.

**Test cases**

| ID | Type | Given | When | Then |
|---|---|---|---|---|
| TC-S11c-01 | H | HR signed in | Ask "headcount by country" | Rows per country with counts |
| TC-S11c-02 | P | Arjun (manager) signed in | Ask for salaries or for Robert's team | No compensation relation; only Arjun's subtree rows |
| TC-S11c-03 | P | Priya (employee) signed in | Ask "show all employees" | Only Priya's own row |
| TC-S11c-04 | N | Model returns `DELETE FROM employees` | Ask anything | Rejected as unsafe; nothing executed |
| TC-S11c-05 | N | Model returns `SELECT * FROM pg_catalog.pg_user` | Ask anything | Rejected as unsafe |
| TC-S11c-06 | E | Same question asked twice by HR | Second ask | Served from cache; no model call |
| TC-S11c-07 | N | User exceeds the per-minute limit | Ask again | `429 rate_limited` |
| TC-S11c-08 | E | Provider times out | Ask | `503 assistant_unavailable`; audit row records the failure |

---

## Future plans

Stories S12–S19 and the end-to-end acceptance story are not part of this build. They are kept, unchanged, in
[`future-plans.md`](future-plans.md) together with the deferred items from the built stories.
