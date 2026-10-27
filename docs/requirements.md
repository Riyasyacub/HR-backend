# HR Platform — Product Requirements Document (Demo)

| Field | Value |
|---|---|
| Version | 0.4 (Demo scope, decisions applied) |
| Date | 2026-10-27 |
| Status | Draft for review |
| Scope | Demo application: candidates, employee hierarchy, HR team |
| Supersedes | v0.3 (demo scope), v0.2 (demo scope), v0.1 (enterprise scope) |
| Companion documents | `docs/product-stories.md` (stories and test cases), `docs/test-plan.md` (sequential test execution) |

---

## 1. Background

The organisation manages roughly **10,000 employees in multiple countries** using Excel workbooks.
This document defines a **demo application** that demonstrates the core HR workflows: recruitment,
onboarding, employee records and hierarchy, leave, attendance, monthly payroll output, and basic
reporting.

The demo is intentionally narrow. It focuses on **candidates, a hierarchy of employees, and a
single HR team**, and proves those workflows end to end. It is not a multi-country compliance,
payroll, benefits, or identity platform.

### 1.1 What changed in this version

| Area | Decision |
|---|---|
| Roles | 4 authenticated roles: **Candidate, Employee, Manager, HR** |
| Candidates | Candidates have their own record and **separate login**; a hired candidate creates an employee record that references the candidate |
| Approvals | Leave follows the **reporting hierarchy**; managers do not approve profile changes |
| Countries | India, USA, and Canada only, as plain data; **no country-specific policies or tax** |
| Currency | Determined by the employee's country: India → INR, USA → USD, Canada → CAD |
| Compensation | **Component breakup supplied in the HR Excel**; **annual CTC** is the sum of the components |
| Payroll | Monthly Excel payout list; unpaid leave **automatically reduces** pay; no tax or deductions |
| Verification | None; data from Excel and forms is accepted as entered |
| Attendance | Overnight CSV upload with employee ID, first-in timestamp, and last-out timestamp |
| Leave | Overnight CSV upload with employee ID, leave type, start date, end date, reason, status |
| Email | **Local SMTP only** (localhost) for the demo |
| Queries | **Removed** from the demo; no helpdesk or HR letter feature |
| Integrations | Email, leave CSV, and time & attendance CSV only |
| Story order | Hiring, onboarding, and offboarding moved to the last phases (S12–S18) |

---

## 2. Goals and scope principles

### 2.1 Goals

| ID | Goal |
|---|---|
| G1 | One employee record per person, replacing the master Excel file |
| G2 | A working reporting hierarchy; leave is approved by the direct manager |
| G3 | Candidates self-serve their applications, and hiring converts them into employees without re-keying |
| G4 | Onboarding and offboarding run as visible checklists with clear ownership |
| G5 | Monthly payroll is produced as one downloadable Excel payout file |
| G6 | HR can answer headcount, leave, attendance, and payroll questions from the app |
| G7 | Attendance data arrives from devices without manual sheets |

### 2.2 Demo success criteria

- 10,000 seeded employees with a multi-level hierarchy load successfully.
- Employees can be imported from an Excel file in one go.
- A candidate can register, log in, apply, and track their application.
- Hiring a candidate creates an employee record that references the candidate.
- Leave requests follow the hierarchy, including a manager's leave going to their own manager.
- A month-end payroll Excel file can be generated with one click and contains bank details.
- Attendance CSV imports and leave/attendance conflicts are visible.
- HR can view headcount, joiners, leavers, leave, attendance, and payroll totals without spreadsheets.

### 2.3 Out of scope

- Statutory or compliance filings, tax calculation, social security, and labour-law rules.
- Country-specific leave policies, holiday calendars, contracts, and payroll rules.
- Benefits administration, performance reviews, and training.
- Payroll calculation beyond monthly gross minus unpaid leave; no tax, deductions, or payslips.
- Identity verification, document authenticity checks, background checks, and e-signature.
- Employee queries, HR helpdesk, ticketing, and HR letter generation.
- Identity provider (SSO/SCIM), payroll provider, calendar, ATS, job board, finance, and background-check integrations.
- Multi-language UI, FX conversion, data residency, and regulatory retention programmes.
- Internal audit tooling; only a lightweight change history is included.

---

## 3. Roles and hierarchy

### 3.1 Roles

| Role | Description | Access |
|---|---|---|
| Candidate | External applicant with an account | Own profile, job openings, own applications and status |
| Employee | Authenticated employee | Own profile, own leave, own attendance, team calendar |
| Manager | An **employee who has at least one direct report**. Not a separately assigned role | Own data plus read access to their reporting subtree; approves leave from direct reports |
| HR | The HR team. Manages employees, candidates, leave balances, payroll runs, reports, and configuration | Full access to all data and settings |

**Rules**

- **R-01** Manager is a property of the hierarchy (having direct reports), not a separately granted permission set.
- **R-02** An employee has at most one direct manager; a manager may themselves report to another manager, with no fixed depth.
- **R-03** Reporting cycles are rejected. Reassigning a manager updates the hierarchy for all affected employees.
- **R-04** HR can reassign managers, including in bulk.
- **R-05** Salary, CTC, components, and bank details are visible to HR and to the employee themselves. Managers do not see their team's compensation or bank details.
- **R-06** A manager sees their full reporting subtree in read-only team views but approves only their direct reports' leave.
- **R-07** HR can act on behalf of any approver with a recorded reason, and can override an approval decision.
- **R-08** Candidates have their own account and record, separate from employees. An employee record created from a hire stores a reference to the candidate record.

### 3.2 Hierarchy-based leave approvals

- **R-09** A leave request routes to the requester's **direct manager**.
- **R-10** If the requester has no manager (for example, a top-level manager or an HR employee), the request routes to the **HR team**.
- **R-11** A manager's own leave request routes to **their** manager, not to themselves.
- **R-12** Self-approval is blocked.
- **R-13** Pending requests are re-routed to the new manager (or HR) when an employee changes manager or leaves.
- **R-14** Managers do **not** approve profile, salary, bank, or country changes; those are HR actions.

### 3.3 Country and currency handling

- **R-15** Country is a field on the employee and candidate record; it does not change approval rules.
- **R-16** Supported countries are **India, USA, and Canada**.
- **R-17** Currency is derived from country: India → **INR**, USA → **USD**, Canada → **CAD**. It is not user-selectable.
- **R-18** HR can move an employee from one country to another with an effective date. The currency changes with the country from that date; history retains the previous country and currency.
- **R-19** Reporting can filter and group by country.
- **R-20** No country-specific leave, tax, holiday, contract, or payroll rules are applied.

---

## 4. Core concepts and data model

| Concept | Definition |
|---|---|
| Candidate | A person with an account who can apply to job openings; has contact details, CV, applications, and login |
| Job opening | A role HR is hiring for: title, country, department, description, status |
| Application | A candidate's application to one job opening, with a pipeline stage and notes |
| Employee | A hired person: personal details, contact, country, department, manager, compensation, bank details, status, and an optional `candidate_id` reference |
| Reporting line | The manager relationship; hierarchy can be nested to any depth |
| Employee status | `onboarding`, `active`, `notice`, `exited` |
| Compensation | A component breakup (component name and annual amount) supplied by HR; annual CTC is the sum |
| Leave type | Global type: earned, sick, casual, or unpaid (unpaid has no balance) |
| Leave balance | Per-employee entitlement, adjustments, and used days per year for earned, sick, and casual |
| Leave request | A dated request with type, reason, status, and approval trail |
| Attendance record | Imported first-in and last-out timestamps for an employee and date |
| Payroll run | A monthly batch of employees and payout amounts, exported to Excel |
| Document | Uploaded file attached to an employee or candidate |
| Audit entry | A lightweight record of who changed what and when |

### 4.1 Data rules

- **DR-01** One employee record per person; a rehire creates a new employment period linked to the same person.
- **DR-02** Every employee change keeps the previous value, the actor, and a timestamp.
- **DR-03** Employees are never hard-deleted; they are marked `exited`.
- **DR-04** Employee ID is unique and immutable. Work email is unique.
- **DR-05** Salary, CTC, components, and bank fields are restricted to HR and the employee.
- **DR-06** No verification: values from Excel imports and candidate or employee forms are stored as submitted.
- **DR-07** Only minimal structural validation is applied: required fields, valid email format, numeric amounts, valid date ranges, and duplicate employee ID/work email rejection.
- **DR-08** Amounts are stored in the currency derived from the employee's country. No currency conversion is performed.
- **DR-09** An employee record created from a hire references the originating candidate record; neither record is deleted.
- **DR-10** Compensation is stored as annual component amounts; annual CTC is derived from their sum. Component names are supplied by HR.

---

## 5. Cross-cutting requirements

Priority: **M** = must (demo), **S** = should, **C** = could.

| ID | Requirement | Priority | Acceptance criteria (summary) |
|---|---|---|---|
| XC-01 | Single employee record used by every workflow | M | No workflow requires a manually exported and re-imported employee list |
| XC-02 | Reporting hierarchy with no cycles and unlimited depth | M | Attempting to create a cycle is rejected; org views show correct levels |
| XC-03 | Role-based access for Candidate, Employee, Manager, and HR | M | Candidates see only their own applications; managers cannot access employees outside their subtree |
| XC-04 | Email notifications for approvals, applications, onboarding, offboarding, and payroll | M | Every defined event sends one email through the local SMTP server |
| XC-05 | Minimal validation; no verification workflows | M | Invalid required fields are blocked; no identity/document verification step exists |
| XC-06 | Excel/CSV import and export (CSV/XLSX) | M | 10,000 employee rows import in under 10 minutes with a row-level error report; leave and attendance arrive via overnight CSV |
| XC-07 | Search and filter employees, candidates, and applications | M | Search respects the user's access scope |
| XC-08 | Document upload for contracts, IDs, and CVs | M | Files are stored against the right record and access-checked |
| XC-09 | Lightweight audit history for changes and approvals | M | HR can see who changed a field, when, and the previous value |
| XC-10 | HR-configurable basics: leave types and entitlements, departments, job openings, email templates | M | HR can edit these in the app without a deployment |
| XC-11 | Responsive UI usable on mobile for leave and approvals | S | Leave CSV upload and manager dashboard complete on a 375 px viewport |
| XC-12 | Simple org chart view of the hierarchy | S | Chart reflects the current manager relationships and can be filtered by country/department |

---

## 6. Functional requirements

### 6.1 Employee master data

**Objective:** One accurate employee record, with hierarchy, history, and HR-controlled changes.

| ID | Requirement | Priority | Acceptance criteria (summary) |
|---|---|---|---|
| EMP-01 | Create an employee from an Excel import, a hired candidate, or manual entry | M | Record has employee ID, name, email, country, department, manager, components, derived annual CTC, bank details, and start date |
| EMP-02 | Excel import with a downloadable template, a preview, and a row-level error report | M | Valid rows are imported; invalid rows are listed with reasons and can be corrected and re-uploaded |
| EMP-03 | Assign or change the direct manager | M | Change is recorded with effective date and actor; hierarchy updates everywhere |
| EMP-04 | Reject hierarchy cycles | M | Selecting a subordinate (directly or indirectly) as manager is blocked |
| EMP-05 | Employee profile: personal details, contact, address, country, department, job title, start date, status | M | Employee can view their own record; HR can edit all fields |
| EMP-06 | Employee self-service for contact details and address | M | Changes save immediately; work email and employee ID are read-only |
| EMP-07 | HR-managed compensation: component breakup and derived annual CTC | M | Annual CTC is the sum of annual components; monthly gross is derived from the components; employees see their own values read-only; managers cannot |
| EMP-08 | HR-managed bank details: bank name, IFSC, and account number | M | Employee sees their own values read-only; changes are audit-logged |
| EMP-09 | Country transfer with effective date | M | Country and currency update from the effective date; previous values remain in history |
| EMP-10 | Employee status lifecycle: onboarding, active, notice, exited | M | Status changes trigger the related checklist and access rules |
| EMP-11 | Employee directory with filters by country, department, manager, and status | M | Results respect the viewer's access scope and reconcile with headcount |
| EMP-12 | Employee history: changes, leave, attendance, payroll lines, documents | S | Timeline is chronological and permission-filtered |
| EMP-13 | Employee record retains a reference to the candidate it was created from | M | Employee view shows the source candidate; candidate view shows the created employee |
| EMP-14 | Rehire of a former employee | S | Prior record remains; new employment starts a new onboarding cycle |

**Business rules**

- BR-EMP-01 Employee ID and work email cannot be changed after creation.
- BR-EMP-02 Only HR can change compensation, bank details, manager, country, and status.
- BR-EMP-03 A manager cannot be their own manager, directly or indirectly.
- BR-EMP-04 An exited employee cannot receive new leave requests or appear in a new payroll run.
- BR-EMP-05 Currency follows the country and cannot be edited independently.

---

### 6.2 Onboarding

**Objective:** Turn a hired candidate into a payroll-ready, app-ready employee through a visible checklist.

| ID | Requirement | Priority | Acceptance criteria (summary) |
|---|---|---|---|
| ONB-01 | Start onboarding from a hired candidate or manually for an off-system hire | M | Employee record is pre-filled from candidate and offer data with no re-keying |
| ONB-02 | Onboarding checklist with owners and due dates | M | Tasks are created automatically and show as pending on the employee and HR views |
| ONB-03 | Collect documents: contract, ID, and policy acknowledgement | M | Documents attach to the employee record; incomplete documents are visible as pending |
| ONB-04 | HR records bank details and components before the first payroll run | M | Employee cannot move to `active` without the fields required by the payroll export; annual CTC is derived from the components |
| ONB-05 | Create the employee's internal app account and send an invite email | M | Employee can log in after accepting the invite; account is inactive before the start date |
| ONB-06 | Manager tasks: team introduction, equipment request, first-week plan | M | Manager sees assigned tasks and completion state |
| ONB-07 | Email notifications and reminders for overdue tasks | M | Reminder emails are sent at configured intervals; completion stops reminders |
| ONB-08 | Mark onboarding complete and set status to `active` | M | Completion requires all mandatory tasks to be done or explicitly waived by HR |
| ONB-09 | Onboarding dashboard for HR: in progress, ready, overdue | S | Counts reconcile with employee records and task status |
| ONB-10 | Cancel onboarding for a no-show and deactivate the account | S | Employee is closed with reason `no_show`; access is revoked |

**Business rules**

- BR-ONB-01 An employee cannot appear in a payroll run before onboarding is complete.
- BR-ONB-02 Account invite is sent only after the employee record exists.
- BR-ONB-03 HR can waive a task with a recorded reason.

---

### 6.3 Offboarding

**Objective:** Close the employment cleanly: final pay inputs, handover, asset return, and app access removed.

| ID | Requirement | Priority | Acceptance criteria (summary) |
|---|---|---|---|
| OFF-01 | HR initiates offboarding with type, reason, notice period, and last working day | M | Employee status becomes `notice`; last working day is stored and editable by HR |
| OFF-02 | Offboarding checklist by task owner: handover, asset return, knowledge transfer, final documents | M | Tasks appear for HR and the manager; overdue tasks are highlighted |
| OFF-03 | Deactivate the employee's internal app access on the last working day | M | Login is blocked automatically at 00:00 on the day after the last working day; HR can deactivate immediately |
| OFF-04 | Record manual access removal for external systems | M | Checklist item requires a named confirmer and timestamp |
| OFF-05 | Final pay inputs: final salary, unused leave payout, and other adjustments recorded as manual amounts | M | Values appear in the next payroll run as a line for the exiting employee |
| OFF-06 | Exit interview date and notes | S | Notes are visible to HR only |
| OFF-07 | Rehire eligibility flag | S | Flag is shown when the person applies again or is rehired |
| OFF-08 | Offboarding dashboard: upcoming exits, overdue tasks | S | Counts reconcile with employee status and tasks |

**Business rules**

- BR-OFF-01 Payroll includes an exiting employee only if their last working day falls in that payroll month or a final-pay adjustment exists.
- BR-OFF-02 App access is disabled on exit even if other checklist tasks are open.
- BR-OFF-03 The employee record remains visible to HR after exit.

---

### 6.4 Payroll output

**Objective:** Produce a monthly Excel payout list with employee, amount, and bank details.
Calculation is limited to monthly gross minus unpaid leave, plus manual adjustments. No tax.

| ID | Requirement | Priority | Acceptance criteria (summary) |
|---|---|---|---|
| PAY-01 | Create a monthly payroll run for a selected month | M | Run includes all `active` employees and excludes employees who exited before the month |
| PAY-02 | Store components; derive annual CTC and monthly gross | M | Annual CTC equals the sum of annual components; monthly gross equals that sum divided by 12, rounded to two decimals |
| PAY-03 | Add one-off adjustments (bonus, deduction, leave payout, correction) | M | Adjustment is visible in the run and audit-logged |
| PAY-04 | Automatically deduct unpaid leave taken in the payroll month | M | Deduction = (monthly gross ÷ working days in month) × unpaid leave days; shown as a separate line |
| PAY-05 | Review the payroll run before export | M | Review shows employee, country, currency, monthly gross, unpaid leave deduction, adjustments, total, and bank details |
| PAY-06 | Export the payout list to Excel | M | File contains employee ID, name, country, currency, bank name, IFSC, account number, monthly gross, unpaid leave deduction, adjustments, total, and pay period |
| PAY-07 | Store payroll history and allow re-download of past runs | M | Every generated run remains available with its original contents |
| PAY-08 | Status lifecycle: draft, generated, paid | S | Generated file is fixed; status can be marked paid with a date |
| PAY-09 | Block export when required data is missing | M | Run cannot be exported while bank name, account number, CTC, or components are missing; affected employees are listed |
| PAY-10 | Simple payroll summary by month, country, and currency | S | Totals reconcile with generated runs |
| PAY-11 | No tax, statutory deductions, benefits, or payslips | M | Product never computes tax, net pay, or payslips |

**Business rules**

- BR-PAY-01 Only HR can create, edit, or export a payroll run.
- BR-PAY-02 Annual CTC = sum of annual components. Monthly gross = that sum ÷ 12. Every employee must have at least one component.
- BR-PAY-03 Unpaid leave is deducted automatically using actual Monday-to-Friday working days in the month.
- BR-PAY-04 Paid leave (earned, sick, casual) does not affect pay.
- BR-PAY-05 Currency follows the employee's country; totals are grouped by currency and never converted.
- BR-PAY-06 A generated run cannot be edited; a new run or adjustment is required.
- BR-PAY-07 Mid-month joins and exits are paid a full month by default; HR adds an adjustment when a pro-rata amount is needed.
- BR-PAY-08 Annual CTC is calculated from the sum of components; there is no independent CTC value to mismatch.

**Payroll Excel columns:** Employee ID, Employee Name, Country, Currency, Bank Name, IFSC,
Account Number, Monthly Gross, Unpaid Leave Deduction, Adjustments, Total Amount, Pay Period, Notes.

---

### 6.5 Leave management

**Objective:** Leave processed via overnight CSV upload. Balances update from approved leave;
unpaid leave is flagged for payroll deduction. Leave types are earned, sick, casual, and unpaid.
No country policies.

| ID | Requirement | Priority | Acceptance criteria (summary) |
|---|---|---|---|
| LVE-01 | HR configures the three balanced types (earned, sick, casual) and their default annual entitlement; unpaid leave has no balance | M | New employees receive default balances for the current year |
| LVE-02 | HR can override an individual employee's entitlement and adjust balances with a reason | M | Adjustment appears in the employee's balance history |
| LVE-03 | Leave CSV includes employee ID, leave type, start date, end date, reason, and status | M | Invalid overlaps and dates outside employment are rejected per row |
| LVE-04 | Balance check at import time | M | Earned, sick, and casual leave cannot exceed the remaining balance; unpaid leave has no limit |
| LVE-05 | Leave status comes from the CSV (pending/approved/rejected) | M | Approved status matches hierarchy routing rules |
| LVE-06 | Approved leave reduces the balance; rejected leave does not | M | Balance updates are audit-logged |
| LVE-07 | Re-uploading the same employee/date updates the record | M | No duplicate leave records are created |
| LVE-09 | Working-day calculation, Monday to Friday, no holiday calendar | M | Weekends are excluded; no country holidays are considered |
| LVE-11 | Employee leave ledger: entitlement, adjustments, used, remaining | M | Ledger totals equal the displayed balance |
| LVE-12 | Balances reset on 1 January; no carryover | M | New year creates fresh balances; prior year remains viewable |
| LVE-14 | Unpaid leave is flagged for payroll deduction | M | Unpaid leave days in a payroll month appear as an automatic deduction |

**Business rules**

- BR-LVE-01 Leave cannot start before the employee's start date or end after the last working day.
- BR-LVE-02 Overlapping requests for the same employee are rejected.
- BR-LVE-03 Only approved leave counts against the balance.
- BR-LVE-04 Cancelling approved leave returns the days to the balance.
- BR-LVE-05 Country does not affect leave types, entitlement, or approval.
- BR-LVE-07 Unpaid leave reduces monthly pay automatically; paid leave does not.

---

### 6.6 Attendance and reconciliation

**Objective:** Import device attendance and surface conflicts with approved leave before payroll.

| ID | Requirement | Priority | Acceptance criteria (summary) |
|---|---|---|---|
| ATT-01 | Import attendance via CSV with employee ID, first-in timestamp, and last-out timestamp | M | Valid rows import; invalid rows are reported with reasons |
| ATT-02 | Re-upload without creating duplicates | M | The same employee/date is updated rather than duplicated |
| ATT-03 | Attendance calendar and daily list per employee | M | Employee sees own records; managers see their subtree; HR sees all |
| ATT-04 | Detect exceptions: missing first-in/last-out, no attendance on a working day, attendance on approved leave | M | Exceptions are listed per date with type and employee |
| ATT-05 | HR can correct a record with a reason | M | Correction is audit-logged and updates the exception state |
| ATT-06 | Mark exception as reviewed or waived | M | Reviewed exceptions are excluded from the open count |
| ATT-07 | Monthly reconciliation view before payroll | M | Shows each employee's approved leave days, attendance days, unpaid leave days, and open exceptions |
| ATT-08 | Export attendance and reconciliation data to CSV/XLSX | S | Export respects filters and permissions |
| ATT-09 | No shifts, overtime rules, geolocation, or device API integration | M | Product does not calculate overtime or require device connectivity |

**Business rules**

- BR-ATT-01 Working days are Monday to Friday, matching leave calculation.
- BR-ATT-02 Attendance is informational and does not automatically change pay; only unpaid leave does.
- BR-ATT-03 An approved leave day with attendance becomes a conflict exception for HR to resolve.
- BR-ATT-04 Missing last-out is an exception; it is not treated as unpaid leave automatically.

---

### 6.7 Reporting

**Objective:** Give HR and managers standard answers without spreadsheets.

| ID | Requirement | Priority | Acceptance criteria (summary) |
|---|---|---|---|
| RPT-01 | Headcount by country, department, manager, and status | M | Totals match the employee list for the same filters |
| RPT-02 | Joiners and leavers for a selected period | M | Lists include start/last working dates and link to employee records |
| RPT-03 | Attrition: leavers divided by average headcount for the period | M | Formula is displayed alongside the value |
| RPT-04 | Leave report: entitlement, used, remaining, unpaid days, and pending requests | M | Totals reconcile with balances and requests |
| RPT-05 | Attendance exception report | M | Counts reconcile with the attendance exception list |
| RPT-06 | Payroll totals by month, country, and currency | M | Totals reconcile with generated payroll runs |
| RPT-07 | Recruitment pipeline report: applications by stage and job opening | S | Counts reconcile with candidate records |
| RPT-08 | Manager dashboard: team headcount, leave today, pending approvals, attendance exceptions | M | Manager sees only their subtree |
| RPT-09 | HR dashboard: headcount, joiners/leavers, pending approvals, payroll status, attendance exceptions | M | Numbers link to the underlying lists |
| RPT-10 | Export report data to CSV/XLSX | M | Export applies current filters and is logged |
| RPT-11 | Headcount trend by month | S | Monthly snapshot values are stored, not recalculated from current data |
| RPT-12 | Role-based restrictions on salary, CTC, and bank data in reports and exports | M | Managers and candidates cannot obtain compensation data from reports |

**Business rules**

- BR-RPT-01 Headcount counts `active` and `notice` employees; `onboarding` and `exited` are shown separately.
- BR-RPT-02 Attrition uses leavers in the period divided by average of opening and closing headcount.
- BR-RPT-03 No currency conversion; payroll totals are grouped by currency.

---

### 6.8 Recruitment

**Objective:** Candidates self-serve applications; HR moves them through the pipeline; hiring hands off to onboarding.

| ID | Requirement | Priority | Acceptance criteria (summary) |
|---|---|---|---|
| REC-01 | HR creates job openings with title, country, department, description, and status | M | Openings can be opened and closed; closed openings reject new applications |
| REC-02 | Candidate registers, logs in, and applies to an open role with a CV and application details | M | Application is linked to the signed-in candidate; duplicate application to the same opening is rejected |
| REC-03 | Candidate profile: name, email, phone, country, CV, password reset | M | Candidate can update their own profile; email is unique and becomes read-only after signup |
| REC-04 | Candidate dashboard listing own applications and current stage | M | Candidate sees only their own applications and no internal notes |
| REC-05 | Candidate pipeline with fixed stages: Applied, Screening, Interview, Offer, Hired, Rejected | M | HR can move an application between stages; every move is timestamped |
| REC-06 | HR candidate view with application data, CV, notes, and stage history | M | HR can add internal notes; notes are never visible to the candidate |
| REC-07 | Record interview date and interviewer; notify the candidate by email | M | Candidate receives interview details by email; no calendar integration |
| REC-08 | Record offer details: components, start date, country, manager, department | M | Offer stage requires at least one component and start date; annual CTC is the component sum; currency follows the country |
| REC-09 | Convert a hired candidate into an employee record | M | Employee is pre-filled from the candidate and offer, stores the candidate reference, and starts onboarding |
| REC-10 | Stage-change and rejection emails using editable templates | M | Emails are sent on configured stage changes |
| REC-11 | Job opening and pipeline dashboard | S | Counts reconcile with applications and openings |
| REC-12 | No job-board posting, sourcing, background checks, e-signature, or interview scheduling integration | M | Product does not integrate with external recruiting services |

**Business rules**

- BR-REC-01 An application belongs to exactly one opening and one candidate.
- BR-REC-02 A candidate can apply to multiple openings; duplicate email per opening is blocked.
- BR-REC-03 Conversion to employee requires the application to be in `Hired`.
- BR-REC-04 Rejected candidates retain their records; deletion is a manual HR action.
- BR-REC-05 A candidate account cannot be converted into an employee login; the employee receives a new employee account.
- BR-REC-06 Every employee created from a candidate keeps the candidate reference permanently.

---

## 7. Non-functional requirements

| ID | Category | Requirement | Priority |
|---|---|---|---|
| NFR-01 | Scale | Support 10,000 employee records and 100 concurrent demo users | M |
| NFR-02 | Performance | p95 page load < 2 s; standard lists < 1 s; 10,000-row import < 10 minutes | M |
| NFR-03 | Availability | Best-effort uptime suitable for a demo; no formal SLA | M |
| NFR-04 | Authentication | Email and password for candidates, employees, and HR; invite flow for employees; JWT-based sessions with hashed passwords; 8-hour inactivity expiry | M |
| NFR-05 | Authorisation | Role checks on every endpoint, plus manager subtree scoping and candidate self-scoping | M |
| NFR-06 | Transport security | HTTPS in deployed environments; HTTP acceptable on localhost | M |
| NFR-07 | Audit | Change history for employee, compensation, bank, leave, payroll, and hierarchy changes; 12-month retention | M |
| NFR-08 | Backups | Daily database backup; restore procedure documented | M |
| NFR-09 | Email | Local SMTP only (localhost); notifications viewable in Mailhog | M |
| NFR-10 | File handling | Type and size limits on uploads; files served only after access checks | M |
| NFR-11 | Localisation | English only; store dates in ISO format and display in the company's format | M |
| NFR-12 | Accessibility | Basic keyboard navigation and readable contrast; no formal WCAG certification | S |
| NFR-13 | Usability | Core tasks complete from the role dashboard without training | M |
| NFR-14 | Observability | Application logs and error tracking sufficient to debug demo failures | M |
| NFR-15 | Data separation | Demo/seed data separated from real data; no production PII in the demo | M |
| NFR-16 | Seed data | Seed script creates 10,000 employees across India, USA, and Canada with a multi-level hierarchy, 100 candidates with applications in various stages, and attendance for the last 2 months; Faker gem may be used; script is repeatable without duplicates | M |
| NFR-17 | Seed performance | Full seed completes within 15 minutes on a development machine | S |

---

## 8. Integrations

| Integration | Direction | Purpose | Priority |
|---|---|---|---|
| Email (local SMTP) | Outbound | Invites, approvals, candidate stage updates, payroll notifications — captured by Mailhog | M |
| Time & attendance devices | Inbound CSV | Employee ID, first-in timestamp, last-out timestamp | M |

No other integrations are in scope. There is no identity provider, payroll provider, calendar,
e-signature, job board, background-check, finance, or messaging integration.

---

## 9. Excel import and export

| Function | Details |
|---|---|
| Employee import template | Employee ID, first name, last name, work email, personal email, phone, country, department, job title, manager employee ID, start date, status |
| Compensation sheet | Employee ID, component name, component annual amount (one row per component); annual CTC is derived from the sum; provided by HR in the same workbook |
| Bank details | Columns in the employee sheet: bank name, IFSC, account number |
| Import behaviour | Download template, upload, preview, validate structure and required fields, import valid rows, report failed rows with row number and reason |
| Duplicate handling | Duplicate employee ID or work email is rejected per row; valid rows still import |
| Manager references | `Manager Employee ID` must reference an existing employee or a row in the same file; the importer resolves managers in a second pass |
| Payroll export | Monthly payout list with employee, country, currency, bank details, monthly gross, unpaid leave deduction, adjustments, total, and pay period |
| Report export | Any standard report can be downloaded as CSV or XLSX |
| No verification | Imported values are not checked against external sources or documents |

The employee Excel sample and the attendance CSV sample will be provided when those features are
implemented.

---

## 10. Permissions matrix

Legend: **✓** allowed · **T** team/subtree scope · **—** denied.

| Capability | Candidate | Employee | Manager | HR |
|---|---|---|---|---|
| Register / log in | ✓ | ✓ | ✓ | ✓ |
| Edit own profile | ✓ | ✓ | ✓ | ✓ |
| Apply to a job opening | ✓ | — | — | — |
| View own applications and stage | ✓ | — | — | — |
| View own employee record | — | ✓ | ✓ | ✓ |
| View own CTC, components, bank | — | ✓ | ✓ | ✓ |
| View team profile | — | — | T | ✓ |
| View team compensation/bank | — | — | — | ✓ |
| Request leave | — | ✓ | ✓ | ✓ |
| Approve leave | — | — | T (direct reports) | ✓ (override) |
| View team leave calendar | — | — | T | ✓ |
| View own attendance | — | ✓ | ✓ | ✓ |
| View team attendance/exceptions | — | — | T | ✓ |
| Correct attendance | — | — | — | ✓ |
| Manage employees and hierarchy | — | — | — | ✓ |
| Manage candidates and openings | — | — | — | ✓ |
| Create/export payroll | — | — | — | ✓ |
| View reports | — | own data | team | ✓ |

---

## 11. Release plan

### MVP (all must requirements)

1. **Foundation:** auth for candidates and employees, roles, hierarchy, employee records, Excel import, audit history.
2. **Employee self-service:** directory, contact updates, change history.
3. **Leave:** overnight CSV upload for earned/sick/casual/unpaid leave, balances with yearly reset, unpaid leave flag for payroll.
4. **Attendance:** overnight CSV import, exceptions, corrections, monthly reconciliation.
5. **Payroll:** monthly run, CTC/components, unpaid leave deduction, adjustments, review, Excel payout export, history.
6. **Reporting:** headcount, joiners/leavers, attrition, leave, attendance, payroll, recruitment pipeline, manager and HR dashboards.
7. **Seed data:** 10,000 employees, 100 candidates, and 2 months of attendance generated with Faker.
8. **Recruitment:** candidate registration/login, job openings, applications, pipeline, offer, conversion to employee with reference.
9. **Onboarding:** checklist, documents, account invite, activation.
10. **Offboarding:** checklist, access deactivation, final pay inputs.

### Should/could (post-demo)

- Org chart, headcount trend, onboarding/offboarding dashboards, rehire handling,
  attendance API integration.

### Definition of done for the demo

- Seed data loads: 10,000 employees across India, USA, and Canada with a multi-level hierarchy,
  100 candidates with applications, and 2 months of attendance.
- End-to-end flow demonstrated: candidate registers → applies → hired → onboarding → leave CSV
  upload → attendance CSV import → payroll Excel → offboarding.
- Leave processed via overnight CSV; balances update from approved leave; unpaid leave flagged
  for payroll deduction.
- Excel import of 10,000 rows completes within the performance target.
- Payroll Excel opens correctly with bank details and unpaid leave deductions.
- Email notifications are visible in the local mail catcher.

---

## 12. Assumptions

- The demo is single-tenant and used by one company; no customer provisioning is required.
- Countries are India, USA, and Canada; country determines currency and nothing else.
- Candidates have accounts and records; employee records created on hire retain a candidate reference.
- Salary is represented as a component breakup supplied by HR; annual CTC is the sum of the
  components. There are no employer contributions, benefits, or tax.
- Monthly gross is the sum of annual components divided by 12. No other calculation is performed.
- Unpaid leave automatically reduces pay; paid leave does not.
- Leave types are earned, sick, and casual with annual balances resetting on 1 January, no carryover;
  unpaid leave is a balance-free type used for leave without pay.
- Working days are Monday to Friday; there is no holiday calendar.
- Attendance arrives as a CSV containing employee ID, first-in timestamp, and last-out timestamp.
- Bank details are bank name, IFSC, and account number; IFSC may be blank for non-Indian records.
- Managers approve leave only; profile, compensation, bank, and country changes are made by HR.
- Email is sent through local SMTP and inspected in a local mail catcher; no external provider.
- The app manages its own accounts; there is no SSO or external directory.
- Employee queries and HR letters are not part of this demo.
- Data entered by candidates or imported from Excel is accepted as-is; no verification is performed.

---

## 13. Decisions and remaining inputs

| # | Topic | Decision |
|---|---|---|
| 1 | Employee Excel sample | To be provided at the time the import feature is implemented |
| 2 | Countries | India, USA, Canada |
| 3 | Leave types | Earned, sick, casual (plus unpaid, balance-free) |
| 4 | Balance reset | Reset yearly on 1 January, no carryover |
| 5 | Compensation | Component breakup imported from the HR Excel; annual CTC is the sum |
| 6 | Unpaid leave and pay | Unpaid leave automatically reduces monthly pay |
| 7 | Bank fields | Bank name, IFSC, account number |
| 8 | Attendance CSV | Employee ID, first-in timestamp, last-out timestamp; sample at implementation |
| 9 | Email | Localhost SMTP only for the demo |
| 10 | Profile changes | Managers do not approve profile changes; HR handles them |
| 11 | Employee queries | Removed from the demo |
| 12 | Candidate access | Separate candidate login; hire creates an employee record referencing the candidate |
| 13 | Seed data | 10,000 employees, 100 candidates, 2 months of attendance; Faker allowed |
| 14 | Currency | Derived from the employee's country (INR, USD, CAD) |

**Still to be supplied during implementation**

- The sample employee Excel workbook (employee fields, CTC, and component breakup).
- The sample attendance CSV from the actual devices.
- Mailhog is the local mail catcher (SMTP `localhost:1025`, UI `http://localhost:8025`).

---

## 14. Glossary

| Term | Meaning |
|---|---|
| Direct manager | The employee's immediate approver in the reporting hierarchy |
| Reporting subtree | All employees below a manager, directly and indirectly |
| CTC | Annual cost to company; the sum of the annual component amounts |
| Component | A named part of CTC (for example, basic or allowance) with an annual amount |
| Monthly gross | The sum of annual components divided by 12 |
| Onboarding | The checklist and data collection between hire and `active` status |
| Offboarding | The checklist and data changes between notice and `exited` status |
| Payroll run | The monthly set of employees, amounts, and adjustments exported to Excel |
| Payout list | The Excel file produced from a payroll run, with bank details and amounts |
| IFSC | Indian bank branch identifier supplied with the bank details |
| Exception | An attendance anomaly: missing punch, absence without leave, or attendance on leave |
| Structural validation | Required-field, format, date-range, and uniqueness checks only; not verification |
