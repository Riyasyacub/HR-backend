# HR Demo — Sequential Test Plan

| Field | Value |
|---|---|
| Version | 1.1 |
| Date | 2026-10-27 |
| Based on | `docs/product-stories.md` v1.1, `docs/requirements.md` v0.4 |
| Approach | Story-by-story, sequential |

## 1. Purpose

This plan explains how to execute the product stories in order, what to prepare before each story,
and how to decide that a story is accepted so the next one can start. Every story builds on data and
behaviour created by earlier stories; skipping ahead invalidates the test data.

## 2. Test levels

| Level | What it covers | When |
|---|---|---|
| Story acceptance | Acceptance criteria and test cases for one story | At the end of each story |
| Regression smoke | Critical paths from all previous stories | Before accepting each story |
| Permission / negative | Role scoping, direct URL access, API access | Within each story |
| Integration | Local SMTP and CSV/Excel file handling | Within the relevant story |
| End-to-end | One continuous candidate-to-offboarding journey | After S18 |
| Performance / scale | 10k seed, import, list, report timings | S11 and targeted checks in S06/S08 |

## 3. Environment and tooling

| Item | Value |
|---|---|
| Application | Rails 8.1.4 API backend + React SPA, local development |
| Frontend repo | `../incubyte-FE` (separate git repository) |
| Frontend tooling | Vite + React + TypeScript; shadcn/ui + Tailwind CSS; Vitest + React Testing Library |
| Database | PostgreSQL 18.6 on `localhost:5432` |
| Email | Local SMTP via Mailhog (SMTP `localhost:1025`, UI `http://localhost:8025`) |
| Browser | Chrome (current), one mobile viewport for S06/S07 |
| File fixtures | `leave_sample.csv`, `leave_invalid.csv`, `attendance_sample.csv`, `attendance_invalid.csv`, `resume.pdf` |
| Time control | Rails time helpers or a test clock for leave reset, notice periods, and session expiry |
| Test data reset | `bin/rails db:reset` followed by the bootstrap and seed commands |

Test data must be reset before a full sequential run. Individual story fixes may preserve the
database as long as the affected story and the regression smoke pack are re-run.

## 4. Accounts

| Account | Role | Created in | Used for |
|---|---|---|---|
| `hr@demo.test` | HR | S01 bootstrap | Every HR flow |
| `meera@demo.test` | Top-level manager | S01 bootstrap | Leave routing to HR, team calendar |
| `arjun@demo.test` | Manager | S01 bootstrap | Leave approvals, scope tests |
| `priya@demo.test` | Employee | S01 bootstrap | Self-service, leave, attendance |
| `robert@demo.test` | Manager (USA) | S01 bootstrap | Cross-country scope |
| `john@demo.test` | Employee (USA) | S01 bootstrap | Payroll and scope |
| `carol@demo.test` | Manager (Canada) | S01 bootstrap | Offboarding manager view |
| `emily@demo.test` | Employee (Canada) | S01 bootstrap | Offboarding tests |
| `nisha@example.test` | Candidate | S12 | Recruitment through hire |

All demo accounts use `Demo@1234` unless noted. The bootstrap creates authentication records and
minimal profiles; S03–S06 complete the employee data.

## 5. Sequential execution plan

Run in this order. The "gate" column is the minimum that must pass before moving on.

| # | Story | Primary focus | Gate |
|---|---|---|---|
| S01 | Sign-in and role access | Auth, role routing, session expiry | All S01 cases green |
| S02 | HR configuration | Countries/currencies, departments, leave types | Settings usable by S03 |
| S03 | Employee records | Create, validate, components with derived CTC, bank | Priya/EMP101 and Canadian/US employees exist |
| S04 | Hierarchy | Manager assignment, cycles, scope | Subtree rules verified |
| S05 | Self-service, directory | Field-level edits, filters, scoping | Directory scoped to viewer |
| S06 | Leave CSV upload | Template, errors, balance updates, scope | Sample file imports cleanly |
| S07 | Attendance CSV upload | CSV validation, upsert, exceptions, scope | Attendance rows loaded |
| S08 | Monthly payroll run | Inclusion, gross, unpaid deduction, adjustments, blocking | Draft run approved |
| S09 | Payroll export | XLSX, immutability, history, paid status | File verified |
| S10 | Reporting | Headcount, attrition, leave, attendance, payroll, pipeline | All reports reconcile |
| S11 | Seed and scale | 10k employees, 100 candidates, 2 months attendance | Seed counts and timings met |
| S12 | Candidate account | Register, login, reset, scoping | Nisha can sign in |
| S13 | Job openings | CRUD, open/closed visibility | One open India role available |
| S14 | Applications | Apply, duplicate, CV limits, own-only | Application in Applied |
| S15 | Pipeline | Stages, notes, interview email, offer, rejection | Application ready to hire |
| S16 | Conversion | Hired → employee, reference, checklist | Onboarding employee exists |
| S17 | Onboarding | Tasks, docs, invite, activation, reminders | Employee `active` with balances |
| S18 | Offboarding | Notice, checklists, deactivation, final pay | Emily exited and excluded |

### Per-story workflow

1. Prepare fixtures and reset data if the story changes shared structures.
2. Run the story's acceptance criteria manually or via automated specs.
3. Run the story's test cases, including negative and permission cases.
4. Run the regression smoke pack (§7).
5. Record results and defects. Do not start the next story while a blocking defect is open.

## 6. Entry and exit criteria

**Entry for each story**

- All earlier stories are accepted.
- Required migrations and configuration are applied.
- Fixtures for the story exist and are valid.
- Mail catcher is running and empty for email-related cases.
- Test accounts and their passwords are available.

**Exit for each story**

- Every acceptance criterion is demonstrated.
- All P0 test cases pass; any skipped case has a documented reason.
- No open severity 1 (blocker) or severity 2 (major) defect.
- Regression smoke pack passes.
- Test data required by the next story exists and is recorded in the run log.

## 7. Regression smoke pack

Run after every story from S03 onward.

| Check | Expected |
|---|---|
| HR sign-in and dashboard | Loads without error |
| Employee sign-in and own profile | Loads; no HR data |
| Employee list and directory | Loads; filters work |
| Create a throwaway employee | Succeeds and is removed or marked exited |
| Hierarchy view | Shows the updated manager structure |
| Leave balance page | Loads for an active employee |
| Attendance list | Loads for HR |
| Mail catcher | Receives test emails |
| Health/seed page | Application responds |

From S07 onward add: leave CSV upload, attendance CSV upload.
From S08 onward add: payroll draft creation.
From S10 onward add: headcount report.
From S12 onward add: candidate sign-in and own applications.

## 8. End-to-end acceptance scenario

Execute only after S18. This is the demo script.

1. Register candidate Nisha, sign in, and apply to the open Software Engineer role.
2. HR moves the application to Screening, then Interview; records an interview; moves to Offer with CTC and start date.
3. HR marks the application Hired and converts it; confirm the employee references the candidate.
4. HR completes onboarding, sends the invitation, and activates the employee on the start date.
5. HR uploads the overnight leave CSV including Nisha's earned leave request; balance decreases.
6. HR uploads the overnight attendance CSV including a day that conflicts with approved leave; conflict is resolved.
7. HR creates and exports the monthly payroll; verify Nisha's row, bank details, gross, unpaid deduction, and total.
8. HR offboards Nisha, enters final pay, and confirms login stops after the last working day.
9. HR opens the dashboards and reconciles headcount, joiners/leavers, attrition, leave, attendance, and payroll totals.

## 9. Performance and scale checks

| Check | Target | Story |
|---|---|---|
| Employee Excel import (10,000 rows) | < 10 minutes | S06 / S11 |
| Leave CSV import (10,000 rows) | < 10 minutes | S06 / S11 |
| Attendance CSV import (10,000 rows) | < 10 minutes | S07 / S11 |
| Standard list load | < 1 s p95 | S05, S11 |
| Page load | < 2 s p95 | S11 |
| Seed 10,000 employees + 100 candidates + 2 months attendance | < 15 minutes | S11 |
| Payroll run for the seeded population | Completes without timeout; record duration | S11 |
| Report export for 10,000 employees | Completes; record duration | S11 |

Performance tests run against the seeded dataset, not against the small functional fixtures.
Record timings in the run log; a regression of more than 20% from the previous run needs review.

## 10. Traceability

| Requirement group | Stories |
|---|---|
| XC-01 single record | S03, S06, S11 |
| XC-02 hierarchy | S04, S10 |
| XC-03 roles and scoping | S01, S12, S05, S10 |
| XC-04 email notifications | S12, S15, S17, S08 |
| XC-05 no verification | S03, S06 |
| XC-06 Excel/CSV import/export | S06, S07, S09, S10 |
| XC-07 search and filters | S05 |
| XC-08 documents | S14, S17 |
| XC-09 audit | S19, S08, S09 |
| XC-10 configuration | S02 |
| XC-11 mobile UI | S06, S07 |
| XC-12 org chart | S04, S10 |
| EMP-01–EMP-14 | S03–S06, S11 |
| ONB-01–ONB-10 | S17 |
| OFF-01–OFF-08 | S18 |
| PAY-01–PAY-11 | S08, S09 |
| LVE-01–LVE-14 | S06 |
| ATT-01–ATT-09 | S07 |
| RPT-01–RPT-12 | S10 |
| REC-01–REC-12 | S12–S16 |
| NFR-01, NFR-02 | S06, S07, S08, S10, S11 |
| NFR-04, NFR-05 | S01, S12 |
| NFR-07, NFR-09 | S05, S17, S09 |
| NFR-16, NFR-17 | S11 |

## 11. Defect severity

| Severity | Definition | Handling |
|---|---|---|
| 1 — Blocker | Data loss, auth bypass, payroll amount wrong, seed fails, app unavailable | Stop the sequence; fix before continuing |
| 2 — Major | A core acceptance criterion fails, email not sent, import/export wrong format | Fix within the story; do not start the next story |
| 3 — Minor | Cosmetic or non-blocking validation issue | Log; may be fixed later in the demo |
| 4 — Trivial | Text, spacing, wording | Log; fix when convenient |

Permission or data-leak defects are always severity 1, regardless of visible impact.

## 12. Assumptions and risks

- The leave CSV and attendance CSV formats are confirmed at implementation; fixtures will be
  regenerated then. If the formats change, S06/S07 cases and S11 seed mappings must be updated.
- Local email is captured by the mail catcher; tests must not depend on external delivery.
- Date-sensitive cases (year reset, notice period, session expiry) use a controllable clock so they
  are repeatable.
- The 10,000-employee seed runs on a development machine; slower machines may need the documented
  timeout adjusted, but the 15-minute target is the acceptance bar.
- Seeded records use a `SEED-` prefix so they can be distinguished from functional fixtures and
  cleaned up without touching story data.
- Re-running the seed must be safe; if it is not, the demo environment must be reset between runs.
- Only one test run should use a shared database at a time; parallel runs will conflict on employee
  IDs, openings, and payroll months.
