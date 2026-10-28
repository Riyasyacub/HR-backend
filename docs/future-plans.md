# Future plans

| Field | Value |
|---|---|
| Date | 2026-10-28 |
| Status | Not scheduled; the build stopped after S11c |
| Source | Moved unchanged from `product-stories.md` |

The stories below were specified but not built. They keep their original IDs, acceptance criteria and test
cases so they can be picked up in order (S12 -> S19), followed by the end-to-end acceptance story.

## Deferred items from the built stories

| From | Item | Planned home |
|---|---|---|
| S08 | Manual payroll adjustments (AC-04, TC-S08-04) | future payroll story |
| S09 | Audit history for export and paid status (AC-06, TC-S09-06) | with audit work |
| S10 | Leavers and attrition (AC-02 leavers, AC-03, TC-S10-02/03) | S18 |
| S10 | Recruitment pipeline report (TC-S10-06); candidate access check (TC-S10-08) | S15 / S12 |
| S10 | Headcount trend snapshots (RPT-11), CSV export, pending approvals, export audit logging | later reporting work |
| S11 | Candidates and applications in the demo seed (AC-03, TC-S11-04) | end of S15 |
| S11 | Employee import preview step | later import work |
| S11c | Verified-examples library with feedback, model escalation, evaluation task | assistant follow-up |
| All | Regression smoke pack from `test-plan.md` §7 | final run |

## S12 — Candidate registration, login, and profile

| | |
|---|---|
| Epic | Hiring |
| Priority | P0 |
| Depends on | S01 |
| Covers | REC-02, REC-03, REC-04, XC-03, NFR-04, R-08 |

**Story**
As a candidate, I want to register and sign in to my own account, so that I can apply for roles and track my applications.

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
| TC-S12-01 | H | No candidate with `nisha@example.test` | Register Nisha Rao with valid details | Candidate record created; signed in; candidate dashboard shown |
| TC-S12-02 | N | Nisha is registered | Register again with `nisha@example.test` | "Email already registered" error; no second record |
| TC-S12-03 | H | Nisha registered | Sign in with correct password | Candidate dashboard loads with profile access |
| TC-S12-04 | I | Nisha registered | Request password reset | Email appears in the local mail catcher; link sets a new password; the link cannot be reused |
| TC-S12-05 | P | Signed in as Nisha | Open `/employees` or an HR page | Access denied |
| TC-S12-06 | N | Signed in as Nisha | Attempt to change email | Field is read-only and the request is rejected |

---

## S13 — Job openings

| | |
|---|---|
| Epic | Hiring |
| Priority | P0 |
| Depends on | S12 |
| Covers | REC-01, REC-11 |

**Story**
As an HR user, I want to create and manage job openings, so that candidates can see and apply for current roles.

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
| TC-S13-01 | H | Signed in as HR | Create "Software Engineer", India, Engineering, open | Opening is saved and listed |
| TC-S13-02 | H | Signed in as HR | Edit the description | Change is saved and visible on the detail page |
| TC-S13-03 | H | Opening is open | Change status to closed | Opening disappears from the candidate list |
| TC-S13-04 | H | Two openings, one closed | Sign in as Nisha and open the openings list | Only the open opening is listed |
| TC-S13-05 | P | Signed in as Nisha | POST to create an opening | Request denied |
| TC-S13-06 | P | Signed in as Nisha | Open a closed opening's URL directly | Not found or closed message; no apply action |

---

## S14 — Job applications

| | |
|---|---|
| Epic | Hiring |
| Priority | P0 |
| Depends on | S13 |
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
| TC-S14-01 | H | Nisha signed in; Software Engineer opening is open | Apply with `resume.pdf` | Application created in stage Applied; visible on Nisha's dashboard |
| TC-S14-02 | N | Nisha already applied to Software Engineer | Apply again to the same opening | Rejected with "already applied" |
| TC-S14-03 | N | Opening is closed | Apply via the direct URL | Rejected; no application is created |
| TC-S14-04 | N | Opening is open | Upload `resume.exe` | Validation error; upload rejected |
| TC-S14-05 | P | Nisha and another candidate both applied | Sign in as Nisha and open the other application URL | Access denied |
| TC-S14-06 | E | Nisha applies to a second, different opening | Submit | A second application is allowed and listed separately |

---

## S15 — Recruitment pipeline, interviews, and offers

| | |
|---|---|
| Epic | Hiring |
| Priority | P0 |
| Depends on | S14 |
| Covers | REC-05 to REC-10, XC-04, R-17 |

**Story**
As a recruiter in the HR team, I want to move candidates through stages, record interviews, and issue offers, so that hiring is tracked and communicated consistently.

**Feature**
- Pipeline stages: Applied → Screening → Interview → Offer → Hired; Rejected from any stage.
- Stage changes timestamped and listed in history.
- Internal notes visible to HR only.
- Interview date and interviewer recorded; candidate gets an email.
- Offer details: components, start date, country, manager, department; annual CTC is the component sum; currency from country.
- Stage-change and rejection emails using editable templates.

**Acceptance criteria**

- **AC-01** HR can advance or reject an application, and every transition is timestamped.
- **AC-02** Candidate sees the current stage but never internal notes.
- **AC-03** Recording an interview sends the candidate an email to the local mail catcher.
- **AC-04** Moving to Offer requires at least one component and start date; annual CTC is their sum and currency follows the opening/offer country.
- **AC-05** Rejecting sends a rejection email and stops further stage changes.
- **AC-06** Offer records can only be created by HR.

**Test cases**

| ID | Type | Given | When | Then |
|---|---|---|---|---|
| TC-S15-01 | H | Nisha's application is in Applied | Move to Screening | Stage updates; history shows timestamp and actor |
| TC-S15-02 | H | Application in Screening | Add internal note "Strong portfolio" | Note visible to HR; not visible on the candidate dashboard |
| TC-S15-03 | I | Application in Interview | Record interview on 2026-11-05 with interviewer Arjun | Candidate email appears in the mail catcher with date and interviewer |
| TC-S15-04 | N | Application in Interview | Move to Offer without CTC | Validation error; stage does not change |
| TC-S15-05 | H | CTC 1,200,000 and start date provided | Move to Offer | Offer saved; currency INR from the India opening |
| TC-S15-06 | H | Application in Screening | Reject with reason | Rejection email sent; candidate dashboard shows Rejected; further stage moves blocked |
| TC-S15-07 | P | Signed in as Nisha | Open the pipeline board | Access denied |

---

## S16 — Convert a hired candidate to an employee

| | |
|---|---|
| Epic | Hiring |
| Priority | P0 |
| Depends on | S15, S03, S04 |
| Covers | REC-09, EMP-13, DR-09, BR-REC-03, BR-REC-06 |

**Story**
As an HR user, I want to convert a hired candidate into an employee record, so that hiring hands off to onboarding without re-entering data.

**Feature**
- Conversion action available only for applications in `Hired`.
- Employee pre-filled from candidate and offer: name, email, phone, country, department, manager, CTC, components, start date.
- Employee record stores a permanent reference to the candidate; both records show the link.
- Conversion creates an onboarding checklist (completed in S17).
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
| TC-S16-01 | H | Nisha's application is Hired with offer data | Convert to employee | Employee created in `onboarding`; name, country, manager, CTC, start date match the offer |
| TC-S16-02 | N | Application is in Offer | Click convert | Action unavailable/rejected |
| TC-S16-03 | H | Employee created from Nisha | Open the employee and candidate records | Employee shows candidate reference; candidate shows created employee |
| TC-S16-04 | N | Nisha already converted | Convert again | Rejected; no second employee |
| TC-S16-05 | H | Conversion complete | Open the onboarding tab | Checklist exists with pending tasks |
| TC-S16-06 | P | Signed in as Nisha (candidate) | Try to convert or open the employee record | Access denied |

---

## S17 — Onboarding checklist, invite, and activation

| | |
|---|---|
| Epic | Onboarding |
| Priority | P0 |
| Depends on | S16 |
| Covers | ONB-01 to ONB-08, OFF-adjacent status rules |

**Story**
As an HR user, I want an onboarding checklist, document collection, and account invite, so that a new employee is fully ready and activated on the start date.

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
| TC-S17-01 | H | Employee created from a hired candidate | Open onboarding | Tasks exist with correct owners and dates |
| TC-S17-02 | H | Onboarding in progress | Upload contract and ID | Documents attach; tasks move to complete |
| TC-S17-03 | I | Employee start date is in the future | Send invite, then try to sign in | Invite email appears in the mail catcher; login is denied until the start date |
| TC-S17-04 | N | Mandatory document task incomplete | Attempt activation | Activation blocked with the missing item listed |
| TC-S17-05 | H | HR waives the incomplete task with reason "joined with prior verified docs" | Activate | Employee becomes `active`; leave balances are created |
| TC-S17-06 | E | Task overdue by 2 days | Run reminders | One reminder email per overdue task; none after completion |
| TC-S17-07 | E | Onboarding in progress | Mark as no-show | Status closed; login blocked; no payroll inclusion |

---

## S18 — Offboarding and access deactivation

| | |
|---|---|
| Epic | Offboarding |
| Priority | P0 |
| Depends on | S17, S09 |
| Covers | OFF-01 to OFF-08, BR-OFF-01 to BR-OFF-03 |

**Story**
As an HR user, I want to offboard an employee with a checklist and automatic access removal, so that the exit is clean and final pay is included.

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
| TC-S18-01 | H | Emily is active | Initiate offboarding with last working day 30 Nov | Status `notice`; date stored; checklist created |
| TC-S18-02 | E | Last working day 30 Nov; simulated date 1 Dec | Employee tries to sign in | Login blocked; session cannot be established |
| TC-S18-03 | H | Offboarding in progress | HR deactivates immediately | Login blocked at once; checklist records the action |
| TC-S18-04 | H | Final pay adjustment of 50,000 entered | Create the next payroll run | Emily appears with the final-pay line |
| TC-S18-05 | H | Exit notes entered | Sign in as Emily's manager (Carol) | Notes are not visible; HR can see them |
| TC-S18-06 | H | Rehire flag set to "eligible" | View the employee record | Flag is displayed to HR |
| TC-S18-07 | E | Emily is exited | Run payroll for the following month | Emily is excluded automatically |
| TC-S18-08 | P | Emily signed in before exit | Request leave after the last working day | Request rejected |

---

## S19 — Employee change history

| | |
|---|---|
| Epic | People |
| Priority | P0 |
| Depends on | S18 |
| Covers | XC-09, NFR-07 (employee records) |

Deferred from S05 to the last phase.

**Story**
As an HR user, I want to see who changed what on an employee record, so that records stay traceable.

**Feature**
- Change history with actor, timestamp, field, old value, and new value.
- Bank account numbers appear masked to the last four digits in history.

**Acceptance criteria**

- **AC-01** Every employee field change creates an audit entry showing old and new values.
- **AC-02** HR, the employee, and managers of the employee's subtree can view the history; others cannot.
- **AC-03** Full bank account numbers never appear in change history.

**Test cases**

| ID | Type | Given | When | Then |
|---|---|---|---|---|
| TC-S19-01 | H | HR changes Priya's department | Open change history | Entry shows actor, timestamp, old department, new department |
| TC-S19-02 | P | Signed in as an employee outside Priya's subtree | Open Priya's change history | Request is denied |
| TC-S19-03 | E | HR changes Priya's bank account number | Open change history | Old and new values show only the last four digits |

---

## End-to-end acceptance story

After S18 passes, run one continuous scenario:

1. Nisha (candidate) registers, signs in, and applies to the open Software Engineer role.
2. HR moves the application through Screening and Interview, records an interview, and creates an offer.
3. HR hires Nisha and converts her to an employee; the employee record references Nisha's candidate record.
4. HR completes onboarding, sends the invite, and activates the employee.
5. HR uploads the overnight leave Excel file including Nisha's earned leave request; balance decreases.
6. HR creates the monthly payroll run and exports the Excel payout file; Nisha's row is present with bank details.
7. HR offboards Nisha with a last working day and a final-pay adjustment; her login stops working.
8. HR opens the dashboard and confirms headcount, attrition, leave, and payroll figures.
