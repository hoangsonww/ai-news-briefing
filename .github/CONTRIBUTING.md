# Contributing to this project

Thanks for taking the time to contribute. Please read this guide before opening a PR or issue.

---

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Workflow](#development-workflow)
- [Branching and Commits](#branching-and-commits)
- [Pull Requests](#pull-requests)
- [Testing](#testing)
- [Reporting Bugs](#reporting-bugs)
- [Requesting Features](#requesting-features)

---

## Code of Conduct

This project follows the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md). By participating, you agree to uphold it.

---

## Getting Started

### Prerequisites

- Node.js 20+
- MongoDB 7+ (or Docker)
- npm 10+

### Setup

```bash
git clone https://github.com/<owner>/this project.git
cd this project
npm install
cp .env.example apps/api/.env
cp .env.example apps/web/.env.local
# Fill in required values in both .env files
npm run dev
```

The API runs on `http://localhost:4000` and the web app on `http://localhost:3000`.

---

## Development Workflow

The repo is a **Turborepo monorepo** with three packages:

| Package | Path | Description |
|---------|------|-------------|
| `@this project/api` | `apps/api` | Express 4 REST API |
| `@this project/web` | `apps/web` | Next.js 14 frontend |
| `@this project/shared-types` | `packages/shared-types` | Zod schemas + TS types |

**Adding a new API endpoint:**
1. Add Zod schema to `packages/shared-types/src/schemas/`
2. Add route in `apps/api/src/routes/`
3. Add controller in `apps/api/src/controllers/`
4. Add service in `apps/api/src/services/`

**Adding a new page:**
1. Create `app/(dashboard)/<route>/page.tsx`
2. Add sidebar link in `components/layout/sidebar.tsx`
3. Create hooks in `hooks/use-<entity>.ts`
4. Create components in `components/<entity>/`

---

## Branching and Commits

- Branch off `main`. Use a short, descriptive branch name:
  - `feat/budget-alerts`
  - `fix/savings-rate-calculation`
  - `docs/helm-readme`
  - `chore/upgrade-mongoose`

- Commit messages should be concise and use the imperative mood:
  - `add spending by day-of-week endpoint`
  - `fix savings rate always returning zero`
  - `update helm chart for production overlay`

- Do not commit directly to `main`.

---

## Pull Requests

- Fill out the PR template completely.
- Keep PRs focused — one logical change per PR.
- All PRs require passing tests and a clean TypeScript build.
- Add screenshots for any UI changes.
- Request review from a maintainer when ready.

**Before submitting:**

```bash
npm run test       # all 330 tests must pass
npm run lint       # TypeScript must compile clean
npm run format     # run Prettier
```

---

## Testing

Tests live in `__tests__/` directories next to their source:

```bash
npm run test                                          # all packages
npx turbo test --filter=@this project/api               # API only
npx turbo test --filter=@this project/web               # web only
npx turbo test --filter=@this project/shared-types      # schema tests only
```

**Rules:**
- Write tests for every function added or modified.
- API service tests use real Mongoose + an in-memory MongoDB server — do not mock the DB.
- Web tests use Vitest + jsdom.
- All tests must pass before a PR can be merged.

---

## Reporting Bugs

Use the [Bug Report](.github/ISSUE_TEMPLATE/bug_report.yml) issue template. Include:

- Steps to reproduce
- Expected vs. actual behavior
- Browser/OS/Node version if relevant
- Relevant logs or screenshots

---

## Requesting Features

Use the [Feature Request](.github/ISSUE_TEMPLATE/feature_request.yml) issue template. Explain the problem you're solving, not just the solution you want.
