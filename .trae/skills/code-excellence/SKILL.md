---
name: code-excellence
description: Universal programming excellence skill. Transforms LLM code output from "correct" to "expert-level" through pattern catalogs, decision trees, anti-pattern recognition, context-aware adaptation strategies, and mandatory generation constraints that prevent simplified "just works" code.
---

# Code Excellence v4

## How LLMs Should Use This Skill

This is not a principles document to read passively. It is an **operating system for code generation**.
Use it as follows:

### Generation Pipeline
```
User Request → [context-branching.md] → Determine context profile
             → [decision-trees.md]    → Identify applicable patterns
             → [design-principles.md] → Apply core principles
             → [patterns.md] /        → Select implementation template
                [patterns-crud.md] /
                [patterns-architecture.md]
             → [anti-patterns.md]     → Avoid known traps
             → [security-patterns.md] → Apply security by design
             → [lang-ref]             → Apply language idioms
             → [Generation Constraints below] → Apply quality gates
             → Generate code
```

### Review Pipeline
```
Generated Code → [review-template.md]   → Structured review
              → [anti-patterns.md]      → Scan for anti-patterns
              → [decision-trees.md]     → Verify decisions match context
              → [security-patterns.md]  → Security review
              → [patterns.md]           → Check pattern implementation fidelity
              → Flag issues or approve
```

### Refactoring Pipeline
```
Legacy/Target Code → [context-branching.md]       → Reassess context
                   → [anti-patterns.md]           → Identify root cause
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

## When to Consult Which File

| Situation | Primary Reference | Secondary |
|-----------|-------------------|-----------|
| Writing new code | `decision-trees.md` → `patterns.md` / `patterns-crud.md` | `design-principles.md` |
| Reviewing code | `review-template.md` → `anti-patterns.md` | `decision-trees.md` |
| Choosing architecture | `context-branching.md` → `patterns-architecture.md` | `decision-trees.md` |
| Resolving design conflicts | `design-principles.md` → `decision-trees.md` | `anti-patterns.md` |
| Refactoring | `anti-patterns.md` → `patterns.md` | `context-branching.md` |
| Debugging | `anti-patterns.md` → `security-patterns.md` | `decision-trees.md` |
| Writing tests | `testing-patterns.md` | `context-branching.md` |
| Security review | `security-patterns.md` | `anti-patterns.md` |
| Language/framework specifics | `java.md` / `kotlin.md` / `golang.md` / `python.md` / `springboot.md` | — |

---

## Generation Constraints (MANDATORY)

These constraints are the difference between "working code" and "production-ready code".

| # | Constraint | Detail Reference |
|---|-----------|-----------------|
| C1 | **Input Validation at Boundary** — validate all external input at the entry point | `design-principles.md` §8 (Fail Fast) |
| C2 | **No Silent Failures** — every failure path has explicit strategy (throw / Result / log+recover) | `anti-patterns.md` AP-3 |
| C3 | **Always Include Tests** — happy path + error path + edge case | `testing-patterns.md` |
| C4 | **Explain Non-Obvious Decisions** — comment the "why" for surprising choices | `patterns-architecture.md` ADR pattern |
| C5 | **No Simplified "Demo" Code** — no `// ... rest`, no skipped error handling, no mock critical paths | — |
| C6 | **Security by Default** — parameterized queries, no secrets in logs, authorization at service layer | `security-patterns.md` |
| C7 | **Resource Cleanup** — deterministic release (try-with-resources / defer / with) | `design-principles.md` §5 (Atomicity) |
| C8 | **Method Length Discipline** — ≤ 60 lines, single level of abstraction | `design-principles.md` §4 |
| C9 | **Atomicity Guarantee** — mutations are all-or-nothing (transaction / Saga / atomic rename) | `design-principles.md` §5 |
| C10 | **Idempotency** — all side-effecting operations support safe retry | `design-principles.md` §6 |

---

## Core Philosophy

The difference between correct code and expert code is knowing:

1. **When to follow a principle and when to break it** — context sensitivity
2. **Which pattern to apply given ambiguous signals** — decision trees
3. **What failure looks like before it happens** — anti-pattern recognition
4. **How to leave room for unknown future change** — evolvability

---

## Quick Expert Checklist

Before finalizing any generated code, verify:

**Structure**
- [ ] Each class has one reason to change? (SRP)
- [ ] Dependency direction points toward stable abstractions?
- [ ] Inheritance used only where truly appropriate? (Composition-first)
- [ ] Module boundaries explicit and respected?

**Robustness**
- [ ] Every external input validated at the boundary? (C1)
- [ ] Error messages contain enough context to diagnose without code? (C2)
- [ ] Idempotency guaranteed for retryable operations? (C10)
- [ ] Atomicity guaranteed for multi-step mutations? (C9)
- [ ] No method exceeds 60 lines? (C8)

**Performance**
- [ ] N+1 queries impossible on this code path?
- [ ] Resources released deterministically? (C7)
- [ ] No premature optimization without profiler evidence?

**Production Readiness**
- [ ] Secrets absent from source code and logs? (C6)
- [ ] Health check exposes critical dependency status?
- [ ] Feature toggles exist for risky changes?
- [ ] Security review passed against `security-patterns.md`?

---

## Reference File Index

| File | Purpose |
|------|---------|
| `design-principles.md` | 10 universal design principles with code examples |
| `context-branching.md` | How recommendations change by project profile (MVP / Scale-Up / Enterprise / Critical Infra) |
| `decision-trees.md` | 20 signal-driven decision trees for design choices |
| `patterns.md` | 16 reusable patterns with multi-language implementations |
| `patterns-crud.md` | Production-grade CRUD controller/service/repository stacks |
| `patterns-architecture.md` | Architect-level patterns (ADR, C4, Bounded Context, Multi-Tenancy) |
| `anti-patterns.md` | 27 wrong-code examples with root cause + expert fix |
| `security-patterns.md` | OWASP mapping, JWT lifecycle, RBAC/ABAC, audit logging |
| `testing-patterns.md` | Given-When-Then, table-driven, property-based, fakes over mocks |
| `review-template.md` | Structured 6-section code review template |
| `java.md` / `kotlin.md` / `golang.md` / `python.md` | Language-specific expert practices |
| `springboot.md` | Spring Boot 3.2+ expert practices (DI, transactions, cache, resilience) |

---

## Limitations

- This skill encodes **transferable expertise patterns**, not exhaustive domain knowledge.
  Domain-specific patterns (e.g., fintech settlement, healthcare FHIR) belong in separate skills.
- The goal is **pragmatic mastery**, not academic perfection.
- All rules have exceptions. The skill teaches you how to *recognize* valid exceptions,
  not to blindly follow rules.

---

## Version History

- **4.0.0** — Added `design-principles.md` (10 core principles extracted from SKILL.md). Added `security-patterns.md`, `patterns-architecture.md`. Added 3 new Generation Constraints (C8-C10). Added Refactoring/Debugging Pipelines. Expanded patterns (+8), anti-patterns (+11), decision trees (+10). SKILL.md now serves as a lean entry point referencing detail files.
- **3.0.0** — Added mandatory Generation Constraints (7 rules), testing patterns, review template, CRUD patterns, multi-language anti-patterns.
- **2.0.0** — Structural transformation: pattern catalog, anti-pattern library, decision trees, context-branching.
- **1.1.0** — Added principle priority, anti‑patterns, quick checklist, API design, immutability.
- **1.0.0** — Initial release.
