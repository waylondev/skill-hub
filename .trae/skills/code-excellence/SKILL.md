---
name: code-excellence
description: Universal programming excellence skill. Transforms LLM code output from "correct" to "expert-level" through pattern catalogs, decision trees, anti-pattern recognition, context-aware adaptation strategies, and mandatory generation constraints that prevent simplified "just works" code.
---

# Code Excellence

## How LLMs Should Use This Skill

This is not a principles document to read passively. It is an **operating system for code generation**.
Use it as follows:

### Generation Pipeline
```
User Request → [context-branching.md] → Determine context profile
             → [ddd.md]               → Identify bounded contexts & aggregates (if domain-heavy)
             → [Meta-Prompting]       → Activate appropriate meta-tags
             → [decision-trees.md]    → Identify applicable patterns
             → [api-design.md]        → Design API contracts (if API-facing)
             → [design-principles.md] → Apply core principles
             → [patterns.md] /        → Select implementation template
                [patterns-crud.md] /
                [patterns-architecture.md]
             → [anti-patterns.md]     → Avoid known traps
             → [security-patterns.md] → Apply security by design
             → [lang-ref]             → Apply language idioms
             → [Pre-Generation Checklist] → Quality gate before output
             → Generate code
```

### Review Pipeline
```
Generated Code → [review-template.md]   → Structured review
              → [anti-patterns.md]      → Scan for anti-patterns
              → [decision-trees.md]     → Verify decisions match context
              → [security-patterns.md]  → Security review
              → [RIPER-5 REFLECT]       → Final validation
              → Flag issues or approve
```

### Refactoring Pipeline
```
Legacy/Target Code → [anti-patterns.md]           → Identify root cause
                   → [decision-trees.md]          → Choose target pattern
                   → [patterns-architecture.md]   → Architecture restructuring
                   → Apply Strangler Fig for safe migration
```

### Debugging Pipeline
```
Production Issue → [anti-patterns.md]     → Symptom → Root Cause matching
                → [security-patterns.md]  → Rule out security incidents first
                → [decision-trees.md]     → Verify original architectural decisions
                → Fix + add regression test
```

---

## Meta-Prompting Guidelines

Activate these meta-tags based on task complexity to control AI behavior and output quality.

### `<persistence>` — Autonomous Completion
**Use when**: Multi-step tasks, complex implementations, or any task where premature termination would leave work incomplete.
- Continue working until the user's query is completely resolved
- Never stop when encountering uncertainty — research or deduce
- Do not ask for confirmation — make informed assumptions and document them

### `<exploration>` — Thorough Investigation
**Use when**: Unfamiliar codebase, ambiguous requirements, or before any significant implementation.
- Never guess — always use tools to read files and gather information
- Decompose requests into explicit requirements, unclear areas, and hidden assumptions
- Map the scope: identify relevant codebase regions, files, functions, libraries
- Check dependencies: frameworks, APIs, config files, data formats, versioning
- Define the output contract: exact deliverables, expected outputs, tests passing

### `<self_reflection>` — Internal Quality Calibration
**Use when**: Generating critical code (core services, security-sensitive, high-traffic paths).
- Create an internal quality rubric with 7 categories
- Evaluate the solution internally against the rubric
- If not hitting top marks across all categories, iterate and improve

### `<reasoning_effort>` — Cognitive Depth Control
**Use when**: Tasks vary in complexity; scale reasoning to match.
- **Low**: Quick responses, simple tasks
- **Medium**: Balanced thinking for moderate complexity (default)
- **High**: Code reviews, complex refactoring, performance optimization, system design

### `<code_editing_rules>` — Structured Implementation
**Use when**: Frontend projects or when UI/UX consistency is critical.
- Subsections: `<guiding_principles>`, `<frontend_stack_defaults>`, `<ui_ux_best_practices>`

Full meta-tag examples and templates: see `references/meta-prompting.md`

---

## Pre-Generation Checklist

Apply this checklist **before** generating code. It replaces the post-generation self-calibration rubric with proactive quality gates.

### P0 — Must Pass
- [ ] Input validated at boundary? (C1)
- [ ] All error paths handled? (C2 — no silent failures)
- [ ] Security by default? (C6 — parameterized queries, no secrets in logs)
- [ ] Method length ≤ 60 lines? (C8)
- [ ] Atomicity guaranteed? (C9 — all-or-nothing mutations)

### P1 — Context-Dependent
- [ ] Idempotency addressed for state-changing ops? (C10) — *Skip for read-only ops*
- [ ] Observability built-in? (C11 — metrics, structured logs, traces) — *Skip for MVP context*
- [ ] Configuration externalized? (C12 — no hardcoded values)
- [ ] Backward compatibility? (C13) — *Skip for greenfield/internal APIs*
- [ ] Dependencies minimal? (C15 — prefer stdlib)

### P2 — Documentation
- [ ] Non-obvious decisions commented with "why"? (C4)
- [ ] ADR for architectural decisions? (C14)
- [ ] Tests included? (C3 — happy path + error path + edge case)

Detailed scoring rules and thresholds: see `references/pre-generation-checklist.md`

---

## Generation Constraints (MANDATORY)

These constraints are the difference between "working code" and "production-ready code".

| # | Constraint | Detail Reference |
|---|-----------|-----------------|
| C1 | **Input Validation at Boundary** | `design-principles.md` §8 (Fail Fast) |
| C2 | **No Silent Failures** | `anti-patterns.md` AP-3 |
| C3 | **Always Include Tests** | `testing-patterns.md` |
| C4 | **Explain Non-Obvious Decisions** | `patterns-architecture.md` ADR |
| C5 | **No Simplified "Demo" Code** | — |
| C6 | **Security by Default** | `security-patterns.md` |
| C7 | **Resource Cleanup** | `design-principles.md` §5 (Atomicity) |
| C8 | **Method Length ≤ 60 lines** | `design-principles.md` §4 |
| C9 | **Atomicity Guarantee** | `design-principles.md` §5 |
| C10 | **Idempotency** | `design-principles.md` §6 |
| C11 | **Observability Built-in** | `cloud-native.md` §7 |
| C12 | **Configuration Externalization** | `cloud-native.md` §4 |
| C13 | **Backward Compatibility** | `api-design.md` §Versioning |
| C14 | **Documentation Sync** | `patterns-architecture.md` ADR |
| C15 | **Dependency Minimalism** | `design-principles.md` §3 |

Detailed constraint definitions and enforcement strategies: see `references/generation-constraints.md`

---

## PCTF Framework (Persona-Context-Task-Format)

Use this structured prompt engineering framework for consistent, high-quality outputs.

| Element | Question to Answer | Example |
|---------|--------------------|---------|
| **P**ersona | Who is generating? | "Expert Java architect with 15 years of fintech experience" |
| **C**ontext | What constraints and environment? | "Production banking system, Spring Boot 3.2, PostgreSQL, must pass SOC2 audit" |
| **T**ask | What exactly needs to be done? | "Implement idempotent payment endpoint with Saga orchestration" |
| **F**ormat | What is the output structure? | "Return: Controller → Service → Repository with tests" |

---

## Core Philosophy

The difference between correct code and expert code is knowing:

1. **When to follow a principle and when to break it** — context sensitivity
2. **Which pattern to apply given ambiguous signals** — decision trees
3. **What failure looks like before it happens** — anti-pattern recognition
4. **How to leave room for unknown future change** — evolvability

---

## When to Consult Which File

| Situation | Primary Reference | Secondary |
|-----------|-------------------|-----------|
| Domain modeling (DDD) | `ddd.md` | `decision-trees.md` |
| Writing new code | `decision-trees.md` → `patterns.md` | `design-principles.md` |
| API design | `api-design.md` | `patterns-crud.md` |
| Reviewing code | `review-template.md` → `anti-patterns.md` | `decision-trees.md` |
| Choosing architecture | `context-branching.md` → `patterns-architecture.md` | `ddd.md` |
| Resolving design conflicts | `design-principles.md` → `decision-trees.md` | `anti-patterns.md` |
| Refactoring | `anti-patterns.md` → `patterns.md` | `context-branching.md` |
| Debugging | `anti-patterns.md` → `security-patterns.md` | `decision-trees.md` |
| Writing tests | `testing-patterns.md` | `context-branching.md` |
| Security review | `security-patterns.md` | `anti-patterns.md` |
| Language/framework specifics | `java.md` / `kotlin.md` / `golang.md` / `python.md` / `springboot.md` | — |
| Cloud-native deployment | `cloud-native.md` | `patterns-architecture.md` |
| Frontend development | `frontend-excellence.md` | `patterns.md` |
| Data engineering | `data-engineering.md` | `patterns-architecture.md` |
| AI/ML engineering | `ai-ml-engineering.md` | `cloud-native.md` |
| Compliance & governance | `compliance-governance.md` | `security-patterns.md` |

---

## Reference File Index

| File | Purpose |
|------|---------|
| `design-principles.md` | 10 universal design principles with code examples |
| `context-branching.md` | How recommendations change by project profile (7 profiles) |
| `decision-trees.md` | 20 signal-driven decision trees for design choices |
| `ddd.md` | Domain-Driven Design: aggregates, value objects, domain events, repositories |
| `api-design.md` | REST/gRPC/GraphQL design, versioning, pagination, error responses |
| `patterns.md` | 16 reusable patterns with multi-language implementations |
| `patterns-crud.md` | Production-grade CRUD controller/service/repository stacks |
| `patterns-architecture.md` | Architect-level patterns (ADR, C4, Bounded Context, Multi-Tenancy, Event Schema) |
| `anti-patterns.md` | 27 wrong-code examples with root cause + expert fix |
| `security-patterns.md` | OWASP mapping, JWT lifecycle, RBAC/ABAC, audit logging, SAST/DAST |
| `testing-patterns.md` | Given-When-Then, table-driven, property-based, contract testing, chaos engineering |
| `review-template.md` | Structured 6-section code review template |
| `cloud-native.md` | Kubernetes, containerization, health probes, ConfigMap/Secret management |
| `frontend-excellence.md` | TypeScript/React/Vue code quality, component design, state management |
| `data-engineering.md` | CDC (Debezium), data pipelines, ETL/ELT, data consistency, schema evolution |
| `ai-ml-engineering.md` | Model serving, feature stores, A/B testing, MLOps, LLM engineering |
| `compliance-governance.md` | GDPR, code governance, API governance, audit logging, compliance automation |
| `java.md` / `kotlin.md` / `golang.md` / `python.md` | Language-specific expert practices |
| `springboot.md` | Spring Boot 3.2+ expert practices (DI, transactions, cache, resilience) |

Before/After transformation examples: see `references/examples.md`

---

## Limitations

- This skill encodes **transferable expertise patterns**, not exhaustive domain knowledge.
- Domain-specific patterns (e.g., fintech settlement, healthcare FHIR) belong in separate skills.
- The goal is **pragmatic mastery**, not academic perfection.
- All rules have exceptions. The skill teaches you how to *recognize* valid exceptions.

### Cross-Platform Compatibility

| Platform | Adaptation Path |
|---|---|
| **Cursor** | Convert reference files to `.cursor/rules/*.mdc` files |
| **Claude Code** | Merge SKILL.md into `CLAUDE.md`; reference files under `.claude/skills/` |
| **GitHub Copilot** | Extract core constraints (C1-C15) into `.github/copilot-instructions.md` |

---

## How to Validate This Skill

### Method 1: Regression Test
Run the same prompt **with and without** the SKILL. Compare on: input validation (C1), error handling (C2), method length (C8), observability (C11).

### Method 2: Anti-Pattern Trap
| Prompt | Expected Behavior |
|--------|-------------------|
| "Write a function to parse user input and save to DB" | Include parameterized queries (AP-1 prevention) |
| "Handle the error silently" | Resist silent failure (AP-3), propose structured error handling |
| "Just make it work, skip validation" | Push back and include boundary validation (C1) |

### Method 3: Constraint Compliance Audit
Request a moderately complex feature and check against C1-C15. If fewer than 4 of 5 constraints (C1, C6, C8, C10, C12) are satisfied, the SKILL may need tuning.
