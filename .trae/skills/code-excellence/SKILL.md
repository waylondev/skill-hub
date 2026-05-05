---
name: code-excellence
description: >
  Universal programming excellence skill. Guides AI to produce clean, simple,
  maintainable code by applying SOLID, DRY, KISS, YAGNI, root‑cause analysis,
  holistic thinking, and timeless design principles. Language‑ and framework‑agnostic.
metadata:
  version: 1.1.0
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
  - java.md
  - kotlin.md
  - golang.md
  - python.md
  - springboot.md
---

# Code Excellence

## Purpose

This skill encodes a set of **language‑agnostic** principles and heuristics that lead to
code that is:

- **Correct** – solves the real problem, not a symptom.
- **Simple** – easy to read, understand, and change.
- **Elegant** – minimal complexity, no over‑engineering.
- **Maintainable** – structured so that future changes are local and safe.

Use this skill whenever you design, write, or review code. It is meant to be applied
**before** any language‑ or framework‑specific reference.

---

## Principle Priority

When principles conflict, apply them in this order:

| Priority | Principle | Rationale |
|----------|-----------|-----------|
| 1 | **Correctness** | A wrong solution, no matter how elegant, is worthless |
| 2 | **KISS** | Simplicity prevents bugs. Prefer simple duplication over wrong abstraction |
| 3 | **Readability** | Code is read far more than written. Clarity > cleverness |
| 4 | **YAGNI** | Resist speculative design. Today's guess is tomorrow's dead code |
| 5 | **DRY** | Eliminate knowledge duplication, not just textual duplication |

**Key insight**: KISS beats DRY. A small amount of deliberate duplication is better than
a premature abstraction that couples unrelated concerns.

---

## Core Design Principles

### SOLID

**Single Responsibility**
- A module / class should have only one reason to change.
- **Heuristic**: Describe the class in one sentence without using "and" or "or". If you can't, split it.
- *Anti‑pattern*: God Class — one class that knows and does everything.

**Open / Closed**
- Open for extension, closed for modification. Add behaviour by adding code, not by changing existing code.
- **Heuristic**: If a new requirement forces you to modify an existing method body (not just add a new method), the design may be too rigid.
- *Anti‑pattern*: Constant `if‑else` chains that grow with every feature.

**Liskov Substitution**
- Subtypes must be substitutable for their base types without altering correctness.
- **Heuristic**: If a subclass throws `UnsupportedOperationException` for an inherited method, the hierarchy is broken.
- *Anti‑pattern*: Square‑extends‑Rectangle — a subclass that violates the parent's contract.

**Interface Segregation**
- Clients should not depend on methods they do not use. Keep interfaces small and focused.
- **Heuristic**: If a caller only uses 2 of 10 interface methods, split the interface.
- *Anti‑pattern*: Swiss Army Knife interface — one giant interface for everything.

**Dependency Inversion**
- Depend on abstractions, not on concretions. High‑level modules should not depend on low‑level modules.
- **Heuristic**: Can you swap the database / queue / HTTP client without touching business logic? If not, the dependency direction is wrong.
- *Anti‑pattern*: Business logic that directly calls `HttpClient.get()` or `Connection.createStatement()`.

### DRY (Don't Repeat Yourself)
- Every piece of knowledge must have a single, unambiguous representation.
- Avoid copy‑paste. Extract common logic, but **do not** create artificial abstractions just to remove duplication when the duplicated code serves different purposes.
- **Heuristic**: Before extracting, ask "will these two pieces always change together for the same reason?" If no, leave them separate.
- *Anti‑pattern*: Wrong abstraction (AHA — Avoid Hasty Abstractions). A shared utility that grows 15 boolean flags to accommodate different callers.

### KISS (Keep It Simple, Stupid)
- Prefer the simplest solution that meets the requirements.
- Complexity is a liability. Add it only when you have evidence that it is necessary.
- **Heuristic**: Could a junior developer understand and modify this code safely? If not, simplify.
- *Anti‑pattern*: Over‑engineering — a 5‑class strategy pattern for a 2‑case conditional.

### YAGNI (You Aren't Gonna Need It)
- Do not build features or abstractions "just in case".
- Every line of code you write today is a line you will have to maintain tomorrow.
- **Heuristic**: "Does a concrete, immediate requirement demand this?" If the answer is "we might need it later", skip it.
- *Anti‑pattern*: Speculative generality — extension points and interfaces for use cases that never materialise.

### Immutability
- Prefer immutable objects. They are inherently thread‑safe, easy to reason about, and never cause aliasing bugs.
- **Heuristic**: Is every field `final` / `val` / `readonly`? If not, can you make it so?
- *Anti‑pattern*: Mutable DTOs with public setters — allowing uncontrolled state changes.

### Separation of Concerns
- Divide a system into distinct sections, each addressing a separate concern.
- A change in one concern should not force changes in unrelated concerns.
- *Anti‑pattern*: Mixing business logic with UI rendering or SQL construction in the same function.

### Principle of Least Astonishment
- Code should behave in a way that is obvious to the reader.
- Naming, structure, and behaviour should align with common expectations.
- **Heuristic**: If a reader says "that's surprising", it's a bug or needs a comment.
- *Anti‑pattern*: A `getUser()` method that creates the user if it doesn't exist. A `List.size()` that has side effects.

---

## Architecture & Design Thinking

- **Start with the domain** – Model the problem space before the solution space. Use the language of the business.
- **Layered architecture** – Separate presentation, business logic, and data access. Depend only on the layer directly below.
- **Ports & Adapters (Hexagonal)** – Keep the core domain independent of infrastructure. Define ports (interfaces) that adapters implement.
- **Keep it flat when possible** – Deep inheritance hierarchies and excessive indirection hurt readability. Prefer composition over inheritance.
- **Design for change** – Identify what is likely to change and isolate it behind a stable interface. Do not try to predict every possible future change.

**Golden rule**: Choose the simplest architecture that solves the problem.
Do not introduce DDD aggregates, CQRS, or event sourcing unless the domain
complexity genuinely demands them.

---

## API Design

- **Contracts are forever** – Once published, an API is a promise. Breaking changes are expensive.
- **Explicit error contracts** – Define error codes and response shapes upfront. Clients should never parse error messages.
- **Idempotency** – `PUT` and `DELETE` should be idempotent. `POST` for non‑idempotent creation. Provide idempotency keys for critical `POST` operations.
- **Backward compatibility** – Add fields, don't remove or rename them. Use versioning (URL path or Accept header) when breaking changes are unavoidable.
- **Pagination from day one** – Any list endpoint must support pagination. The default page size should be conservative.

---

## Code Style & Readability

- **Names are documentation** – Use intention‑revealing names. A reader should understand what a variable, function, or class does without reading its implementation.
- **Small, focused functions** – A function should do one thing. Line count is a *signal*, not a hard rule. A function that does one thing well at 30 lines is better than one that does three things at 15. If a function exceeds ~30 lines, verify it still has a single responsibility.
- **Avoid magic values** – Replace hard‑coded numbers and strings with named constants or enums.
- **Comments explain "why", not "what"** – The code itself should be clear enough to explain what it does. Use comments for intent, trade‑offs, and non‑obvious constraints.
- **Consistent formatting** – Use automated formatters. Consistency reduces cognitive load.

---

## Error Handling & Robustness

- **Fail fast** – Validate inputs at the boundary. Throw a clear, specific exception as soon as an invalid state is detected.
- **Do not swallow exceptions** – If you catch an exception, either handle it meaningfully or let it propagate. Silent failures are bugs.
- **Provide context** – Error messages should include enough information to diagnose the problem (e.g. input values, operation name).
- **Separate business exceptions from technical exceptions** – Use distinct exception types so callers can react appropriately.

---

## Testing & Quality

- **Test behaviour, not implementation** – Tests should verify *what* the code does, not *how* it does it. This allows safe refactoring.
- **Test pyramid** – Many fast unit tests, fewer integration tests, very few end‑to‑end tests.
- **Design for testability** – Use dependency injection and interfaces. Avoid static state and global singletons.
- **High coverage on critical paths** – Core business logic should have near‑100% branch coverage.

---

## Problem Solving & Root‑Cause Analysis

- **Find the root cause** – When a bug appears, ask "why" repeatedly until you reach the underlying issue. Fixing symptoms wastes time and creates new bugs.
- **Think holistically** – Before changing code, understand how it fits into the larger system. A local fix that breaks a distant component is not a fix.
- **Minimal fix** – Change only what is necessary to correct the problem. Avoid "while I'm here" refactoring in the same commit.
- **Verify the fix** – Write a test that reproduces the bug, confirm it fails, apply the fix, and watch it pass.

---

## Performance & Resource Management

- **Correctness first, performance second** – Make it work, make it right, then make it fast (only if measurements show it is needed).
- **No premature optimisation** – Guessing about performance bottlenecks is unreliable. Use a profiler.
- **Release resources deterministically** – Use language constructs that guarantee cleanup (try‑with‑resources, `defer`, `using`, context managers).
- **Be mindful of N+1 queries** – Batch database operations and use eager loading where appropriate.

---

## Security Awareness

- **Never trust external input** – Validate and sanitise all data that crosses a trust boundary.
- **Least privilege** – Services and database accounts should have the minimum permissions required.
- **Protect secrets** – Never hard‑code credentials, tokens, or keys. Use environment variables or a secrets manager.
- **Keep dependencies up‑to‑date** – Regularly scan for known vulnerabilities.

---

## Observability

- **Structured logging** – Emit logs in a machine‑parseable format (JSON). Include a correlation id (trace id) that flows across services.
- **Log at the right level** – DEBUG for development, INFO for key business events, WARN for recoverable anomalies, ERROR for human intervention.
- **Expose metrics** – Track throughput, latency, error rate, and business KPIs.

---

## Configuration & Environment

- **Externalise configuration** – Everything that changes between environments belongs in configuration files or environment variables, never in code.
- **Support multiple environments** – Provide clear separation for dev, test, staging, and production.
- **Encrypt sensitive configuration** – Production secrets must be encrypted at rest and in transit.

---

## Version Control & Collaboration

- **Semantic versioning** – `MAJOR.MINOR.PATCH`. Increment MAJOR for breaking changes, MINOR for backward‑compatible features, PATCH for fixes.
- **Meaningful commits** – Follow Conventional Commits (`feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`).
- **Code review** – Every change is reviewed by at least one other person. Review for design, correctness, readability, and security.
- **Keep the main branch releasable** – All tests must pass on main at all times.

---

## How to Use This Skill

1. **Before writing code** – Read the Core Design Principles and Architecture sections. Let them shape your mental model.
2. **While writing code** – Refer to Code Style, Error Handling, and Testing sections. Apply them continuously.
3. **During code review** – Use this document as a checklist. If a piece of code violates a principle, discuss whether the violation is justified.
4. **When debugging** – Follow the Problem Solving section. Resist the urge to patch symptoms.
5. **For language specifics** – After applying this skill, consult the appropriate language reference (`java.md`, `kotlin.md`, `golang.md`, `python.md`) or framework reference (`springboot.md`).

---

## Quick Checklist

Use this as a lightweight review gate:

**Design**
- [ ] Each class / module has a single reason to change?
- [ ] Dependencies point toward abstractions, not concretions?
- [ ] Architecture is the simplest that could possibly work?

**Code**
- [ ] Names reveal intent without requiring implementation reading?
- [ ] No magic numbers or hard‑coded strings?
- [ ] Functions do one thing and are not brittle‑long?

**Safety**
- [ ] External input is validated at the boundary?
- [ ] Errors carry enough context to diagnose the issue?
- [ ] No secrets in source code?

**Behaviour**
- [ ] Tests verify what the code does, not how it does it?
- [ ] Critical business paths have thorough coverage?
- [ ] Fixes are verified by a test that reproduces the bug?

---

## Limitations

- This skill provides **guidelines**, not rigid rules. There are valid reasons to deviate, but the deviation should be conscious and documented.
- It does **not** cover language‑specific idioms, framework configuration, or tool setup. Those belong in separate, focused references (e.g. `java.md`, `springboot.md`, `golang.md`).
- The goal is **pragmatic excellence**, not theoretical purity. A working, simple solution that slightly bends a principle is better than an over‑engineered masterpiece that never ships.

---

## Version History

- **1.1.0** – Added principle priority section, anti‑patterns, quick checklist, API design section, immutability principle, trigger conditions, and updated references to decoupled `java.md` / `kotlin.md` / `springboot.md` / `golang.md` / `python.md`.
- **1.0.0** – Initial release. Covers SOLID, DRY, KISS, YAGNI, architecture thinking, code style, error handling, testing, root‑cause analysis, performance, security, observability, configuration, and collaboration.
