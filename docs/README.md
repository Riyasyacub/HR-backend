# Product Documentation

| Document | Contents |
|---|---|
| [`requirements.md`](requirements.md) | Product requirements for the HR demo (v0.3): scope, roles, hierarchy, data model, 119 requirements, decisions |
| [`product-stories.md`](product-stories.md) | 22 sequential stories (S01–S22), each with a testable feature, acceptance criteria, and 158 test cases |
| [`test-plan.md`](test-plan.md) | Sequential execution plan, environments, accounts, regression pack, end-to-end script, traceability, defect severity |
| [`api.md`](api.md) | JSON conventions, error envelope, and endpoint contracts as they are implemented |

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

S01, S02, and S03 are complete. S03 delivers authoritative employee records:
- Backend: `Employee`, append-only `Compensation` and `CompensationComponent` models, annual CTC derived from component sums, `Employees::Create` service, HR-only list and create endpoints, and HR/self profile show endpoint with `EmployeePolicy`.
- Frontend: `employees` API client, `CompensationInputs` with dynamic components and auto-calculated annual CTC, `useNewEmployeeForm` hook, `EmployeesPage` list, `NewEmployeePage` creation form, and `EmployeeProfilePage` read-only bank/compensation view.
All 134 backend specs and 51 frontend tests pass. S04 (Reporting hierarchy and manager scope) is next. Implementation follows the story order in `product-stories.md`.
