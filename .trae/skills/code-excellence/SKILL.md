---
name: code-excellence
description: >
  Universal programming excellence skill. Transforms LLM code output from
  "correct" to "expert-level" through pattern catalogs, decision trees,
  anti-pattern recognition, and context-aware adaptation strategies.
metadata:
  version: 2.0.0
  category: foundation
  priority: high
  language_agnostic: true
triggers:
  - code_generation
  - code_review
  - refactoring
  - architecture_design
  - debugging
  - user_mentions_best_practices_or_principles
references:
  - patterns.md
  - anti-patterns.md
  - decision-trees.md
  - context-branching.md
  - java.md
  - kotlin.md
  - golang.md
  - python.md
  - springboot.md
---

# Code Excellence v2

## How LLMs Should Use This Skill

This is not a principles document to read passively. It is an **operating system for code generation**.
Use it as follows:

### Generation Pipeline
```
User Request → [context-branching.md] → Determine context profile
             → [decision-trees.md]    → Identify applicable patterns
             → [patterns.md]          → Select implementation template
             → [anti-patterns.md]     → Avoid known traps
             → [lang-ref]             → Apply language idioms
             → Generate code
```

### Review Pipeline
```
Generated Code → [anti-patterns.md]   → Scan for anti-patterns
              → [decision-trees.md]    → Verify decisions match context
              → [patterns.md]          → Check pattern implementation fidelity
              → Flag issues or approve
```

### When to Consult Which File

| Situation | Primary Reference | Secondary |
|-----------|-------------------|-----------|
| Writing new code | `decision-trees.md` → `patterns.md` | `anti-patterns.md` |
| Reviewing code | `anti-patterns.md` | `decision-trees.md` |
| Choosing architecture | `context-branching.md` | `decision-trees.md` |
| Refactoring | `anti-patterns.md` → `patterns.md` | `context-branching.md` |
| Debugging | `anti-patterns.md` (symptom→root cause) | `decision-trees.md` |
| Language/framework specifics | `java.md` / `kotlin.md` / `golang.md` / `python.md` / `springboot.md` | — |

---

## Core Philosophy

The difference between correct code and expert code is **not** knowing more principles.
It is knowing:

1. **When to follow a principle and when to break it** — context sensitivity
2. **Which pattern to apply given ambiguous signals** — decision trees
3. **What failure looks like before it happens** — anti-pattern recognition
4. **How to leave room for unknown future change** — evolvability

### Principle Priority (for conflict resolution)

| Priority | Principle | Signal |
|----------|-----------|--------|
| 1 | **Correctness** | If it produces wrong output, nothing else matters |
| 2 | **Safety** | No data loss, no security breach, no silent corruption |
| 3 | **Simplicity (KISS)** | Could this be understood in 6 months by someone else? |
| 4 | **Evolvability** | Will the next likely change require touching 1 file or 20? |
| 5 | **Consistency** | Does this follow the patterns already established in the codebase? |
| 6 | **DRY** | Extract only when two pieces share the same reason to change |

---

## Quick Expert Checklist

Before finalizing any generated code, verify:

**Structure**
- [ ] Each class has one reason to change? (Describe it without "and"/"or")
- [ ] Dependency direction points toward stable abstractions?
- [ ] New code extends rather than modifies existing tested code?

**Robustness**
- [ ] Every external input validated at the boundary?
- [ ] Error messages contain enough context to diagnose without reading code?
- [ ] Idempotency guaranteed for non-idempotent operations that can be retried?

**Performance awareness**
- [ ] N+1 queries impossible on this code path?
- [ ] Resources (connections, files, locks) released deterministically?
- [ ] No premature optimization without profiler evidence?

**Production readiness**
- [ ] Secrets absent from source code and logs?
- [ ] Health check exposes critical dependency status?
- [ ] Feature toggles exist for risky changes?

---

## Limitations

- This skill encodes **transferable expertise patterns**, not exhaustive domain knowledge.
  Domain-specific patterns (e.g., fintech settlement, healthcare FHIR) belong in separate skills.
- The goal is **pragmatic mastery**, not academic perfection.
- All rules have exceptions. The skill teaches you how to *recognize* valid exceptions,
  not to blindly follow rules.

---

## Version History

- **2.0.0** — Structural transformation: pattern catalog, anti-pattern library, decision trees,
  context-branching. Upgraded all language references with deep expertise content.
- **1.1.0** — Added principle priority, anti‑patterns, quick checklist, API design, immutability,
  trigger conditions, decoupled language/framework references.
- **1.0.0** — Initial release.
