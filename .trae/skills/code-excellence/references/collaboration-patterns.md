# Collaboration Patterns — Architect-Level Reference

## Purpose

Engineering leadership patterns that architects use to scale team productivity, enforce quality gates, manage technical decisions, and learn from failures. These patterns bridge the gap between "good code" and "good engineering culture."

---

## CL-1: Git Branching Strategy

**Use when**: Establishing or revising team branching policy. The branching strategy directly impacts deployment frequency, code review quality, and release risk.

### ❌ Wrong — Ad-Hoc Branching

```
- No naming convention: branch names like "fix", "test123", "final-v2"
- Direct commits to main/master
- Long-lived feature branches (3+ weeks without merging)
- No branch protection rules
- Hotfix merged to main but not to develop → regressions reappear
```

### Root Cause

Without a branching convention, the repository becomes incomprehensible. Long-lived branches create merge hell. Skipping branch protection means unreviewed code reaches production.

### ✅ Expert Fix — Trunk-Based Development (Recommended for most teams)

```
Trunk-Based Development for teams of 2-50:
- Branch: feature/<ticket-id>-<short-desc>   (max 2 days lifetime)
- Branch: fix/<ticket-id>-<short-desc>
- Branch: hotfix/<version>-<short-desc>      (from tag, merged to both main + develop)
- Branch: release/<version>                   (freeze for QA, only bug fixes)
```

```yaml
# .github/repo-settings.yml — Branch Protection
branches:
  main:
    protection:
      required_reviews: 1              # at least 1 approval
      required_approving_review_count: 1
      dismiss_stale_reviews: true      # new commit = re-review
      require_code_owner_review: true  # CODEOWNERS must approve
      required_status_checks:
        - "build-and-test"
        - "lint"
        - "security-scan"
      enforce_admins: true             # even admins can't bypass
      restrictions: null               # no push without PR
      linear_history: true             # squash merge only

  develop:
    protection:
      required_reviews: 1
      required_status_checks:
        - "build-and-test"
        - "lint"
```

```ini
# .github/CODEOWNERS
# Architecture-critical paths require architect approval
**/patterns-architecture.md     @architecture-team
**/security-patterns.md         @security-team
src/main/java/**/config/        @platform-team
src/main/resources/db/migration/ @dba-team
*.tf                            @infra-team
Dockerfile                      @infra-team
```

**Branching Strategy Decision Matrix:**

| Factor | Trunk-Based | GitFlow | GitHub Flow |
|--------|-------------|---------|-------------|
| Team size | 2-50 | 20+ | 2-10 |
| Release cadence | Daily/Continuous | Scheduled (weekly+) | Continuous |
| Long-term releases | ❌ Needs adaptation | ✅ Native support | ❌ |
| Merge complexity | Very Low | High | Low |
| Best for | SaaS, microservices | Enterprise on-prem, mobile apps | Open source, small SaaS |

**PR Size Guidelines:**
```
< 200 lines  → Ideal, quick review
200-400 lines → Acceptable, may need 2 reviewers
400-800 lines → Split if possible, flag for senior review
> 800 lines  → MUST split into stacked PRs, architecture review required
```

**Expert Note**: Trunk-Based is the modern default. The discipline of merging daily forces incremental design and prevents merge hell. The counter-argument ("we need long feature branches for complex features") is a symptom of poor modularization — complex features should be built behind feature toggles (RF-3), not in long-lived branches.

---

## CL-2: Conventional Commits + Semantic Versioning

**Use when**: Automating release notes, version bumping, and changelog generation. Required for any project with consumers who depend on version numbers.

### ❌ Wrong — Arbitrary Commit Messages

```
commit 1: "fix"
commit 2: "updated stuff"
commit 3: "final fix v2"
commit 4: "BREAKING: changed API response"  (buried in message body)

Release notes: manual. Version bumps: manual. Mistakes: frequent.
```

### ✅ Expert Fix — Conventional Commits

```yaml
# commitlint.config.js
module.exports = {
  extends: ['@commitlint/config-conventional'],
  rules: {
    'type-enum': [2, 'always', [
      'feat',      # new feature (MINOR bump)
      'fix',       # bug fix (PATCH bump)
      'docs',      # documentation only
      'style',     # formatting, no code change
      'refactor',  # code change, no feature/fix
      'perf',      # performance improvement
      'test',      # adding/updating tests
      'chore',     # build, CI, dependencies
      'revert'     # reverts a previous commit
    ]],
    'scope-case': [2, 'always', 'lower-case'],
    'subject-case': [2, 'always', 'lower-case'],
    'body-max-line-length': [2, 'always', 100],
    'footer-max-line-length': [2, 'always', 100]
  }
};
```

```
# Commit format
<type>(<scope>): <description>

[optional body]

[optional footer]

# Examples
feat(orders): add idempotent payment endpoint           → MINOR bump
fix(payment): retry timeout not applied to charge calls  → PATCH bump
feat(api)!: change order response from List to Page      → MAJOR bump (! or BREAKING CHANGE:)
```

```yaml
# .github/workflows/release.yml
# Auto-generate release on push to main
jobs:
  release:
    steps:
      - uses: google-github-actions/release-please-action@v3
        with:
          release-type: java    # analyzes commits since last release
          # feat: → MINOR, fix: → PATCH, BREAKING → MAJOR
```

**Commit → Version Bump:**
| Commit Prefix | Semantic Version | Example |
|---------------|-----------------|---------|
| `fix:` | **PATCH** (1.2.3 → 1.2.4) | Bug fix, no API change |
| `feat:` | **MINOR** (1.2.3 → 1.3.0) | New feature, backward compatible |
| `feat!:` or `BREAKING CHANGE:` | **MAJOR** (1.2.3 → 2.0.0) | Breaking API change |

**Expert Note**: Conventional Commits is the cheapest automation investment a team can make. For the cost of a standardized prefix, you get: automated changelogs, automated version bumps, automated release notes. The discipline also forces developers to think about the impact of their changes before committing — a `feat!` commit (breaking change) requires explicit acknowledgment.

---

## CL-3: Code Review Workflow

**Use when**: Establishing or improving code review culture. Code review is the primary quality gate between "written" and "shipped."

### ❌ Wrong — Rubber-Stamp Review

```
Reviewer: "LGTM 👍" (Looks Good To Me)
- No code checked out locally
- No tests run
- No security review
- Approved in 30 seconds
- PR merged with 3 unresolved architectural concerns

Result: Review = ceremony, not quality gate.
```

### ✅ Expert Fix — Review Pyramid

```
Code Review Depth by Layer (top = fastest, bottom = deepest):

  [Style / Formatting]     → AUTOMATED (lint, formatter). Never review manually.
  [Naming / Clarity]       → Quick scan: do names tell the story?
  [Test Coverage]          → Do tests cover: happy path + error path + edge case? (C3)
  [Design / Patterns]      → Does this align with our decision trees?
  [Architecture / Security] → ARCHITECT REVIEW: ADR needed? Security review passed?
```

```markdown
# Code Review Checklist (aligned with C1-C15)

## Every PR — Reviewer MUST Verify:
- [ ] C1: Input validation at boundary? (no trust from caller)
- [ ] C2: All error paths handled? (no empty catch blocks)
- [ ] C3: Tests cover happy/error/edge cases?
- [ ] C6: No secrets in logs/config? Parameterized queries?
- [ ] C8: Any method > 60 lines? (flag for refactor)

## Architecture-Impact PRs — Architect MUST Verify:
- [ ] C4: Non-obvious decisions commented with "why"?
- [ ] C10: Idempotency for POST/PATCH/Payment endpoints?
- [ ] C13: Backward compatibility maintained? (API versions, deprecation headers)
- [ ] C14: ADR written for architectural decisions?
- [ ] C15: New dependency justified? (every dependency is a liability)
```

```ini
# CODEOWNERS — Architectural Review Gates
# These paths require approval from the listed teams

# Database migrations — DBA review
src/main/resources/db/migration/*.sql  @dba-team

# Security patterns — Security review
src/main/java/**/security/            @security-team
src/main/java/**/auth/                @security-team

# API contracts — Architecture review
src/main/java/**/api/                 @architecture-team
src/main/java/**/dto/                 @architecture-team

# Infrastructure — Platform review
docker-compose*.yml                   @platform-team
Dockerfile                            @platform-team
.github/workflows/                    @platform-team
```

**Review SLA:**
| PR Size | Max Review Latency | Min Review Depth |
|---------|--------------------|--------------------|
| < 200 lines | 2 hours | Full (all checklist items) |
| 200-400 lines | 4 hours | Full |
| 400-800 lines | 24 hours | Full + Architecture review |
| > 800 lines | Split request | — |

**Expert Note**: The review pyramid exists because human attention is finite. Automate everything at the bottom (style, formatting, static analysis). Reserve human review for things machines cannot judge: naming clarity, design coherence, architectural fit. The CODEOWNERS file is your architectural enforcement mechanism — make it granular and keep it updated.

---

## CL-4: ADR Lifecycle Management

**Use when**: Making architectural decisions that need to be tracked, revisited, and potentially superseded over the system's lifetime.

### ❌ Wrong — Oral Tradition Architecture

```
"Why did we choose MongoDB for the analytics service?"
"I think Bob said something about SQL being slow..."
"No wait, maybe it was for the flexible schema?"

Result: Nobody knows. Bob left 8 months ago. Now MongoDB is causing problems
and nobody can justify or undo the decision.
```

### ✅ Expert Fix — ADR Lifecycle

```markdown
# ADR-0012: Use PostgreSQL JSONB for Product Attributes

## Status
Proposed (2026-01-10) → Accepted (2026-01-15) → Superseded by ADR-0023 (2026-08-01)

## Context
[What is the problem we're solving? What forces are at play?]

## Decision
[What did we decide? Clear, actionable, specific.]

## Consequences
### Positive
- Developers are familiar with PostgreSQL — no training needed
- ACID guarantees — no eventual consistency surprises

### Negative
- JSONB queries are less intuitive than MongoDB-style queries
- Mitigation: Provided attribute accessor utility class

### Risks
- JSONB column may grow large if uncontrolled
- Mitigation: Set max attribute count = 50 per product

## Alternatives Considered
1. **MongoDB for catalog only** — Rejected: adds second database, operational complexity
2. **EAV pattern (entity-attribute-value table)** — Rejected: query performance < 50ms target at 10M products
3. **Flat columns (200 columns)** — Rejected: schema change overhead, 80+ NULL columns

## Related
- Supersedes: ADR-0008 (product schema v1)
- Superseded by: ADR-0023 (migrated to dedicated search service)
- Depends on: ADR-0005 (PostgreSQL version upgrade to 16)
```

**ADR Directory Structure:**
```
docs/adr/
├── README.md                # ADR index with status summary
├── 0001-record-architecture-decisions.md
├── 0002-use-postgresql-as-primary-db.md
├── 0003-use-kafka-for-event-driven-communication.md
│   Status: Accepted (2025-06)
├── 0004-use-rest-over-grpc.md
│   Status: Superseded by ADR-0011 (2026-03)
├── ...
└── templates/
    └── adr-template.md
```

**ADR Status Transitions:**
```
[Proposed] → [Accepted] → [Superseded] or [Deprecated]
     ↓
[Rejected] (kept for historical reference — documents why we did NOT choose X)
```

**Expert Note**: ADRs are not documentation — they are decision provenance. The most valuable ADR is a rejected one: it prevents revisiting the same argument 6 months later with a new team. Each ADR should be findable by the question it answers ("Why did we choose X over Y?"). The ADR directory becomes the team's institutional memory.

---

## CL-5: Blameless Incident Postmortem

**Use when**: A production incident occurs (P1/P2 severity). The goal is learning and prevention, not blame.

### ❌ Wrong — Blame-Oriented Postmortem

```
"Who deployed the broken config?"
"Why didn't QA catch this?"
"Bob should have tested his code better."

Result: Team hides incidents. Root causes go unfixed. Same incidents recur.
Fear culture → brittle systems.
```

### ✅ Expert Fix — Blameless Postmortem Template

```markdown
# Incident Postmortem: Payment Service Degradation

## Summary
- **Incident ID**: INC-2026-042
- **Date**: 2026-05-12, 14:23 UTC → 15:47 UTC (duration: 1h 24m)
- **Severity**: P1 — Payment processing failed for 23% of transactions
- **Impact**: 4,821 affected transactions, $12,340 in missed revenue, 147 customer complaints
- **Status**: Resolved and Verified

## Timeline (All times UTC)
| Time | Event |
|------|-------|
| 14:23 | New payment service instance deployed (v3.2.1) |
| 14:25 | Payment failure rate jumps from 0.01% → 23% |
| 14:28 | PagerDuty alert: payment-error-rate threshold breached |
| 14:30 | On-call engineer begins investigation |
| 14:35 | Identified: new instance has stale connection pool config |
| 14:40 | Incident commander declares P1, assembles response team |
| 14:42 | **Mitigation**: Rollback to v3.2.0 — payment failure rate drops to 0.01% |
| 14:45 | Verification: all payment services healthy, backlog clearing |
| 15:00 | Monitoring confirms: 0 customer-impacting errors for 15 minutes |
| 15:30 | Post-incident review: root cause confirmed |
| 15:47 | Incident declared resolved |

## Root Cause Analysis (5 Whys)
1. **Why** did payments fail? → Connection pool exhausted (timeout errors)
2. **Why** was the pool exhausted? → New instance had `max-pool-size=1` (config error)
3. **Why** was the config wrong? → Helm values file had wrong default, not overridden per environment
4. **Why** wasn't this caught? → Smoke tests don't run at production traffic volumes
5. **Why** don't smoke tests simulate load? → No load generation in CI pipeline

**Root Cause**: Helm chart default `max-pool-size=1` not overridden. Staging uses minimal traffic → never triggers.

## Contributing Factors
- No canary deployment — 100% rollout instantly (mapped to: missing **RF-3 Feature Toggle + RF-1 Strangler Fig**)
- No pre-flight connection pool validation — service starts with invalid pool silently
- Alert fired but no automated rollback — manual intervention added 14 minutes

## Action Items
| # | Action | Owner | Deadline | Severity |
|---|--------|-------|----------|----------|
| 1 | Add connection pool validation at startup (fail-fast, C8) | @platform-team | 2026-05-19 | P0 |
| 2 | Implement canary deployment (1% → 10% → 100%) | @devops | 2026-05-26 | P0 |
| 3 | Add HikariCP `leak-detection-threshold` to all services | @dev-leads | 2026-05-26 | P1 |
| 4 | Add load-based smoke tests to CI (100 RPS for 30s) | @qa-team | 2026-06-02 | P1 |
| 5 | Create `helm lint` rule: reject `max-pool-size=1` in prod values | @platform-team | 2026-05-19 | P1 |

## Lessons Learned
1. **Default config values are production config values** — there is no "just a default."
2. **Startup validation > runtime failure detection** — fail fast at boot, not 23% into traffic (see: C1, design-principles §8).
3. **Canary deployment is not optional for revenue-critical services** — Strangler Fig (RF-1) applies to version upgrades too.
```

**Postmortem Timing:**
- P1 incidents: Postmortem within 48 hours
- P2 incidents: Postmortem within 1 week
- P3/P4: Lightweight postmortem within sprint

**Expert Note**: The 5 Whys is powerful precisely because it's simple. It forces you past the first obvious answer ("config was wrong") to the systemic root cause ("why was wrong config deployable?"). Action items must have owners and deadlines — without them, a postmortem is just a story. Link action items to the anti-pattern (AP-xx) or constraint (Cx) they address.

---

## Quick Collaboration Checklist

- [ ] Branching strategy documented and enforced via branch protection rules?
- [ ] CODEOWNERS file covering architecture-critical paths?
- [ ] Commitlint enforcing Conventional Commits in CI?
- [ ] Automated release notes and version bumping (semantic-release)?
- [ ] Code review checklist aligned with C1-C15?
- [ ] Review SLA defined and team committed?
- [ ] ADR directory exists with template and index?
- [ ] Every significant architectural decision has an ADR (including rejected alternatives)?
- [ ] Postmortem template defined and linked to anti-patterns/constraints?
- [ ] Post-incident action items track to completion with owners and deadlines?
