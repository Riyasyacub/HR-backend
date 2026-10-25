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

S01 is complete. Roles, demo accounts, server-side sessions, access tokens, sign-in, refresh
rotation, sign-out, current-user authentication, the React sign-in screen, protected routing,
role-aware dashboards, and HR-only settings access are implemented. S02 is next.
Implementation should follow the story order in `product-stories.md`.
