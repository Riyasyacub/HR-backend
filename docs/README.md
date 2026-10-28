# Product Documentation

| Document | Contents |
|---|---|
| [`requirements.md`](requirements.md) | Product requirements for the HR demo (v0.3): scope, roles, hierarchy, data model, 119 requirements, decisions |
| [`product-stories.md`](product-stories.md) | 18 sequential stories (S01–S18), each with a testable feature, acceptance criteria, and 143 test cases |
| [`future-plans.md`](future-plans.md) | Unbuilt stories S12–S19, the end-to-end acceptance story, and deferred items from built stories |
| [`test-plan.md`](test-plan.md) | Sequential execution plan, environments, accounts, regression pack, end-to-end script, traceability, defect severity |
| [`api.md`](api.md) | JSON conventions, error envelope, and endpoint contracts as they are implemented |
| [`architecture.md`](architecture.md) | System context, backend layers, auth flow, import / payroll / assistant workflows, data model, frontend structure (Mermaid diagrams) |
| [`trade-offs.md`](trade-offs.md) | Key decisions, the alternatives considered, and what each choice costs |
| [`performance.md`](performance.md) | Measured timings, query patterns, indexes, bulk processing, assistant cost controls, known limits |

## Reading order

1. **Requirements** — what the demo must do and what it deliberately excludes.
2. **Product stories** — how the product is built and tested, one slice at a time.
3. **Test plan** — how to run the slices in order and decide each one is done.
4. **API contract** — the request and response shapes for each endpoint.

## Conventions

- Stories are numbered `S01`–`S22` and must be built and tested sequentially; each assumes earlier stories are complete.
- Test cases are numbered `TC-S<story>-<number>` and typed **H** (happy), **N** (negative), **E** (edge), **P** (permission), **I** (integration), **PF** (performance).
- Requirement IDs in stories map back to `requirements.md` (`EMP-01`, `LVE-03`, `NFR-02`, and so on).

## Current stage

S01–S04 are complete and committed. S05 (Employee self-service and directory) is next.

Completed stories:
- S01 — Sign-in and role-based access: auth, JWT, roles, sessions, React sign-in, protected routing
- S02 — HR configuration: countries, departments, leave types
- S03 — Create and manage employee records: compensation components, derived CTC, bank details, profiles
- S04 — Reporting hierarchy and manager scope: manager assignment, cycles, subtree views

Remaining stories (S05–S19):
- S05 — Employee self-service and directory
- S06 — Leave Excel upload (overnight)
- S07 — Attendance CSV upload (cut)
- S08 — Monthly payroll run
- S09 — Payroll Excel export and history
- S10 — Reporting dashboards and exports
- S11 — Demo seed data and scale verification
- S12 — Candidate registration, login, and profile
- S13 — Job openings
- S14 — Job applications
- S15 — Recruitment pipeline, interviews, and offers
- S16 — Convert a hired candidate to an employee
- S17 — Onboarding checklist, invite, and activation
- S18 — Offboarding and access deactivation
- S19 — Employee change history (deferred from S05)

Implementation follows the story order in `product-stories.md`.
