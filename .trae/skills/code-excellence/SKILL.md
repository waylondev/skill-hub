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
             → [Meta-Prompting]       → Activate appropriate meta-tags
             → [decision-trees.md]    → Identify applicable patterns
             → [Self-Reflection]      → Internal quality rubric check
             → [design-principles.md] → Apply core principles
             → [patterns.md] /        → Select implementation template
                [patterns-crud.md] /
                [patterns-architecture.md]
             → [anti-patterns.md]     → Avoid known traps
             → [security-patterns.md] → Apply security by design
             → [lang-ref]             → Apply language idioms
             → [Generation Constraints C1-C15] → Apply quality gates
             → Generate code
```

### Review Pipeline
```
Generated Code → [review-template.md]   → Structured review
              → [anti-patterns.md]      → Scan for anti-patterns
              → [decision-trees.md]     → Verify decisions match context
              → [security-patterns.md]  → Security review
              → [Self-Reflection]       → Internal quality rubric
              → [RIPER-5 REFLECT]       → Final validation
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

## Meta-Prompting Guidelines

Activate these meta-tags based on task complexity to control AI behavior and output quality.

### `<persistence>` — Autonomous Completion
**Use when**: Multi-step tasks, complex implementations, or any task where premature termination would leave work incomplete.

**Behaviors**:
- Continue working until the user's query is completely resolved
- Only terminate when the problem is definitively solved
- Never stop when encountering uncertainty — research or deduce the most reasonable approach and continue
- Do not ask for confirmation or clarification — make informed assumptions and document them

**Example**:
```
<persistence>
- You are an agent — please keep going until the user's query is completely resolved
- Only terminate your turn when you are sure that the problem is solved
- Never stop when you encounter uncertainty
</persistence>
```

### `<exploration>` — Thorough Investigation
**Use when**: Unfamiliar codebase, ambiguous requirements, or before any significant implementation.

**Behaviors**:
- Never guess — always use tools to read files and gather information
- Decompose requests into explicit requirements, unclear areas, and hidden assumptions
- Map the scope: identify relevant codebase regions, files, functions, libraries
- Check dependencies: frameworks, APIs, config files, data formats, versioning
- Define the output contract: exact deliverables, expected outputs, tests passing

**Example**:
```
<exploration>
Before coding, always:
- Decompose the request into explicit requirements, unclear areas, and hidden assumptions
- Map the scope: identify the codebase regions, files, functions, or libraries likely involved
- Check dependencies: frameworks, APIs, config files, data formats, versioning
- Resolve ambiguity proactively based on repo context and conventions
- Define the output contract: exact deliverables, tests passing, etc.
- Formulate an execution plan with research and testing strategy
</exploration>
```

### `<self_reflection>` — Internal Quality Calibration
**Use when**: Generating critical code (core services, security-sensitive, high-traffic paths).

**Behaviors**:
- Create an internal quality rubric with 7 categories (see AI Self-Calibration below)
- Evaluate the solution internally against the rubric
- If not hitting top marks across all categories, iterate and improve
- Do not show the rubric to users — it is for internal quality control

**Example**:
```
<self_reflection>
- Create a rubric with 7 categories for evaluating solution quality
- Think deeply about every aspect of what makes for a world-class solution
- Use the rubric to internally iterate on the best possible solution
- If your response is not hitting top marks across all categories, start again and improve
</self_reflection>
```

### `<reasoning_effort>` — Cognitive Depth Control
**Use when**: Tasks vary in complexity; scale reasoning to match.

**Levels**:
- **Low**: Quick responses, simple tasks, well-defined problems
- **Medium**: Balanced thinking for moderate complexity (default)
- **High**: Deep analysis, multi-step reasoning, complex problem-solving

**When to use HIGH**:
- Code reviews requiring security and architecture analysis
- Complex refactoring decisions
- Multi-file impact analysis
- Performance optimization requiring algorithmic changes
- System design and architecture decisions

**Example**:
```
<reasoning_effort>
For this code review task requiring security analysis, architecture evaluation,
and cross-file impact assessment, use HIGH reasoning effort to ensure comprehensive
analysis across all dimensions.
</reasoning_effort>
```

### `<code_editing_rules>` — Structured Implementation
**Use when**: Frontend projects or when UI/UX consistency is critical.

**Subsections**:
- `<guiding_principles>`: Clarity and reuse, consistency, simplicity, visual quality
- `<frontend_stack_defaults>`: Framework (Next.js/TS), styling (Tailwind), UI components (shadcn/ui), state (Zustand)
- `<ui_ux_best_practices>`: Visual hierarchy, spacing, hover states, responsive design

---

## AI Self-Calibration Mechanism

Before generating critical code (core services, security-sensitive modules, high-traffic paths), perform an internal quality assessment.

### Internal Quality Rubric (7 Dimensions)

| Dimension | Weight | Criteria |
|-----------|--------|----------|
| **Correctness** | 20% | Handles all specified requirements; no logical flaws; edge cases covered |
| **Security** | 20% | Input validated; no injection risks; secrets protected; authz enforced |
| **Testability** | 15% | Dependencies injectable; side effects isolated; testable without heavy infra |
| **Observability** | 15% | Metrics exposed; logs structured; errors traceable; health checks present |
| **Performance** | 10% | No N+1 queries; resource-efficient; no premature optimization |
| **Maintainability** | 10% | Clear naming; single responsibility; ≤ 60 lines per method; documented "why" |
| **Consistency** | 10% | Follows project conventions; matches existing patterns; no style violations |

### Scoring Rules
- Score each dimension 0-100
- Calculate weighted total
- **Threshold**: Total ≥ 90 required for critical code
- **Action if < 90**: Identify weakest dimensions, redesign those aspects, re-score
- **Maximum iterations**: 3; if still < 90 after 3 iterations, document trade-offs and proceed with explicit warnings

### When to Apply
- Core domain services (OrderService, PaymentService, UserService)
- Authentication/authorization code
- API endpoints handling sensitive data
- Infrastructure/configuration code
- Any code with "if this breaks, the system is down" risk

---

## PCTF Framework (Persona-Context-Task-Format)

Use this structured prompt engineering framework to ensure consistent, high-quality outputs across all code generation and review tasks.

### The Four Elements

| Element | Question to Answer | Example (Code Generation) | Example (Code Review) |
|---------|--------------------|--------------------------|----------------------|
| **P**ersona | Who is generating/reviewing? | "Expert Java architect with 15 years of fintech experience" | "Principal engineer performing security-focused code review" |
| **C**ontext | What constraints and environment? | "Production banking system, Spring Boot 3.2, PostgreSQL, must pass SOC2 audit" | "Payment service codebase, critical path, regulatory compliance required" |
| **T**ask | What exactly needs to be done? | "Implement idempotent payment endpoint with Saga orchestration" | "Scan for AP-1 through AP-27, verify all C1-C15 constraints" |
| **F**ormat | What is the output structure? | "Return: Controller → Service → Repository with tests" | "Output: Executive Summary → Critical → Warning → Suggestion → Approval Status" |

### Application Examples

**Code Generation**:
```
Persona: Senior backend engineer expert in distributed systems
Context:  Scale-Up e-commerce, Java 21 + Spring Boot 3.2, PostgreSQL, Redis,
          CI/CD with feature flags, 99.9% SLO target
Task:    Create order checkout endpoint with idempotency, transaction boundary,
         and outbox-based event publishing
Format:  Controller DTO + Service with @Transactional + Repository with projection query
         + integration tests with Testcontainers
```

**Code Review**:
```
Persona: Security architect conducting compliance review
Context:  Enterprise fintech application, PCI-DSS compliance required,
          100K+ TPS peak load
Task:    Review payment processing module for security, performance, and compliance gaps
Format:  Structured output with severity levels + CWE references + fix recommendations
```

**Refactoring**:
```
Persona: Architecture modernization specialist
Context:  10-year-old monolith being decomposed via Strangler Fig,
          concurrent refactoring by multiple teams
Task:    Extract notification module into separate bounded context
Format:  ADR with context/decision/consequences + migration plan + ArchUnit fitness functions
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
| Cloud-native deployment | `cloud-native.md` | `patterns-architecture.md` |
| Frontend development | `frontend-excellence.md` | `patterns.md` |
| Data engineering | `data-engineering.md` | `patterns-architecture.md` |
| AI/ML engineering | `ai-ml-engineering.md` | `cloud-native.md` |
| Compliance & governance | `compliance-governance.md` | `security-patterns.md` |

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
| C11 | **Observability Built-in** — critical paths expose metrics, structured logs, and distributed traces | `cloud-native.md` §7 |
| C12 | **Configuration Externalization** — config separated from code; environment-driven; no hardcoded values | `cloud-native.md` §4 |
| C13 | **Backward Compatibility** — API changes guarantee N-1 compatibility; deprecation before removal | `compliance-governance.md` §3 |
| C14 | **Documentation Sync** — code changes synchronize docs/comments; ADR for architectural decisions | `patterns-architecture.md` ADR pattern |
| C15 | **Dependency Minimalism** — new dependencies require explicit justification; prefer stdlib | `design-principles.md` §3 |

---

## Core Philosophy

The difference between correct code and expert code is knowing:

1. **When to follow a principle and when to break it** — context sensitivity
2. **Which pattern to apply given ambiguous signals** — decision trees
3. **What failure looks like before it happens** — anti-pattern recognition
4. **How to leave room for unknown future change** — evolvability

---

## Community Landscape Benchmark

This SKILL is not the only approach to improving AI-generated code quality. Here is how it positions among community practices (as of 2026):

| Project / Practice | Focus | How code-excellence Differs |
|---|---|---|
| **Anthropic Official Skill Best Practices** | Meta-guidance on writing Skills (conciseness, progressive disclosure, degrees of freedom, model testing) | code-excellence *is* a Skill built on these principles; it is the "what" while Anthropic's guide is the "how to build" |
| **Claude Playbook** (smartwhale8/claude-playbook) | Production-ready `.claude/` scaffolding with rules, skills, agents, hooks | code-excellence is **language-agnostic** and covers 4 pipelines (generate/review/refactor/debug); Playbook ties rules to specific stacks |
| **Awesome CLAUDE.md** (TakatoPhy/awesome-claude-md) | Curated CLAUDE.md templates & examples by project type | code-excellence is **principle-driven** (decision trees, anti-patterns) rather than template-driven; deeper quality reasoning |
| **andrej-karpathy-skills** (18.3K stars) | Karpathy's LLM coding rules: think first, simplicity, surgical changes, goal-driven | code-excellence complements these with **pipeline architecture** — Karpathy rules define *behavior*, code-excellence defines *process* |
| **Cursor Rules Ecosystem** (.cursor/rules/*.mdc) | Project-level AI rules scoped by glob patterns / always / manual | code-excellence is **context-branching aware** — rules adapt per project profile (MVP vs Enterprise vs Critical Infra); Cursor rules are static |
| **Everything Claude Code** (153K stars) | Battle-tested agents, skills, hooks, commands, MCP configs for Claude Code | code-excellence is **self-contained** — no external MCP/agent dependencies; focused purely on code quality patterns |

### code-excellence's Four Differentiators

1. **Language-Agnostic** — patterns work across Java, Kotlin, Go, Python, TypeScript; community solutions are mostly stack-specific
2. **Principle-Driven Pipelines** — 4 structured pipelines (Generation / Review / Refactoring / Debugging) rather than flat rule lists
3. **Full Lifecycle Coverage** — spans code generation, review, refactoring, and debugging in one unified skill
4. **Built-in AI Self-Calibration** — 7-dimension quality rubric with automated re-generation threshold, unique among community practices

---

## Before/After Transformation Examples

These examples show how code-excellence principles transform "working code" into "expert-level code".

### Example 1: CRUD Controller — Input Validation + Idempotency (C1, C10)

**Before (working but fragile):**
```java
@PostMapping("/orders")
public Order createOrder(@RequestBody OrderRequest req) {
    Order order = new Order(req.getProductId(), req.getQuantity());
    return orderRepository.save(order);
}
```

**After (expert-level):**
```java
@PostMapping("/orders")
public Order createOrder(@Valid @RequestBody OrderRequest req,
                         @RequestHeader("Idempotency-Key") String idempotencyKey) {
    return orderService.createOrder(req, idempotencyKey);
}
// In service layer: validate boundary, check idempotency, atomic persistence
```

### Example 2: Error Handling — Silent Failure → Observable (C2, AP-3)

**Before (swallows the error):**
```python
def process_payment(amount):
    try:
        gateway.charge(amount)
    except Exception:
        pass
```

**After (observable with context):**
```python
def process_payment(amount, order_id):
    try:
        gateway.charge(amount)
    except PaymentGatewayError as e:
        logger.error("payment_failed", extra={
            "order_id": order_id, "amount": amount, "gateway_error": str(e)
        })
        raise PaymentFailedException(order_id=order_id, reason=str(e))
```

### Example 3: Configuration — Hardcoded → Externalized (C12)

**Before (hardcoded):**
```go
db, _ := sql.Open("postgres", "host=10.0.1.5 user=admin password=secret123 dbname=prod")
```

**After (environment-driven):**
```go
db, err := sql.Open("postgres", os.Getenv("DATABASE_URL"))
if err != nil { logger.Fatal("db_connection_failed", "error", err) }
```

### Example 4: Database Query — N+1 → Batch Loading (Performance)

**Before (N+1 queries):**
```kotlin
fun getOrdersWithItems(userId: Long): List<Order> {
    return orderRepo.findByUserId(userId).map { order ->
        order.copy(items = itemRepo.findByOrderId(order.id))
    }
}
```

**After (single batch query):**
```kotlin
fun getOrdersWithItems(userId: Long): List<Order> {
    val orders = orderRepo.findByUserId(userId)
    val orderIds = orders.map { it.id }
    val itemsByOrderId = itemRepo.findByOrderIdIn(orderIds).groupBy { it.orderId }
    return orders.map { it.copy(items = itemsByOrderId[it.id] ?: emptyList()) }
}
```

### Example 5: API Evolution — Breaking Change → Backward Compatible (C13)

**Before (direct change, breaks all clients):**
```java
// v1: GET /api/users → { "name": "..." }
// Changed to: GET /api/users → { "fullName": "..." }  ❌ BREAKING
```

**After (versioned with deprecation):**
```java
// GET /api/v1/users → { "name": "..." }                     (supported, deprecated header set)
// GET /api/v2/users → { "fullName": "...", "name": "..." }  (backward-compatible, includes v1 field)
```

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

**Observability & Governance**
- [ ] Critical paths expose metrics, logs, and traces? (C11)
- [ ] Configuration externalized from code? (C12)
- [ ] API changes maintain backward compatibility? (C13)
- [ ] Documentation/comments synchronized with code? (C14)
- [ ] New dependencies justified and minimal? (C15)

---

## Reference File Index

| File | Purpose |
|------|---------|
| `design-principles.md` | 10 universal design principles with code examples |
| `context-branching.md` | How recommendations change by project profile (MVP / Scale-Up / Enterprise / Critical Infra / AI-ML / Frontend / Mobile) |
| `decision-trees.md` | 20 signal-driven decision trees for design choices |
| `patterns.md` | 16 reusable patterns with multi-language implementations |
| `patterns-crud.md` | Production-grade CRUD controller/service/repository stacks |
| `patterns-architecture.md` | Architect-level patterns (ADR, C4, Bounded Context, Multi-Tenancy, Event Schema Evolution) |
| `anti-patterns.md` | 27 wrong-code examples with root cause + expert fix |
| `security-patterns.md` | OWASP mapping, JWT lifecycle, RBAC/ABAC, audit logging, SAST/DAST, supply chain security |
| `testing-patterns.md` | Given-When-Then, table-driven, property-based, fakes over mocks, chaos engineering, contract testing |
| `review-template.md` | Structured 6-section code review template |
| `cloud-native.md` | Kubernetes, containerization, Sidecar, health probes, ConfigMap/Secret management |
| `frontend-excellence.md` | TypeScript/React/Vue code quality, component design, state management, performance |
| `data-engineering.md` | CDC (Debezium), data pipelines, ETL/ELT, data consistency, schema evolution |
| `ai-ml-engineering.md` | Model serving, feature stores, A/B testing, MLOps, LLM engineering |
| `compliance-governance.md` | GDPR, code governance (SonarQube), API governance, audit logging, compliance automation |
| `java.md` / `kotlin.md` / `golang.md` / `python.md` | Language-specific expert practices |
| `springboot.md` | Spring Boot 3.2+ expert practices (DI, transactions, cache, resilience) |

---

## Limitations

- This skill encodes **transferable expertise patterns**, not exhaustive domain knowledge.
  Domain-specific patterns (e.g., fintech settlement, healthcare FHIR) belong in separate skills.
- The goal is **pragmatic mastery**, not academic perfection.
- All rules have exceptions. The skill teaches you how to *recognize* valid exceptions,
  not to blindly follow rules.

### Cross-Platform Compatibility

This SKILL is designed for the **Trae IDE SKILL system** (`<skill>` invocation + `SKILL.md` entry point + reference files). The underlying principles are platform-agnostic and can be adapted to other AI coding assistants:

| Platform | Adaptation Path |
|---|---|
| **Cursor** | Convert reference files to `.cursor/rules/*.mdc` files; pipelines become project rules with `alwaysApply` |
| **Claude Code** | Merge SKILL.md into `CLAUDE.md`; reference files go under `.claude/skills/code-excellence/` |
| **GitHub Copilot** | Extract core constraints (C1-C15) into `.github/copilot-instructions.md` |

The Before/After examples and Core Philosophy apply universally regardless of platform.

---

## How to Validate This Skill

After activating this SKILL in your project, use these methods to verify it is shaping code quality as intended:

### Method 1: Regression Test
Run the same code-generation prompt **with and without** the SKILL activated. Compare outputs on:
- Presence of input validation (C1)
- Error handling strategy (C2, AP-3)
- Method length discipline (C8)
- Observability hooks (C11)

**Example prompt**: "Create a REST endpoint for creating a user account with email and password."

### Method 2: Anti-Pattern Trap
Deliberately request code that triggers known anti-patterns. Verify the SKILL catches or prevents them:

| Prompt | Expected SKILL Behavior |
|---|---|
| "Write a function to parse user input and save to DB" | Should include parameterized queries (AP-1 prevention) |
| "Handle the error silently" | Should resist silent failure (AP-3), propose structured error handling |
| "Just make it work, skip validation" | Should push back and include boundary validation (C1) |

### Method 3: Constraint Compliance Audit
Request a moderately complex feature and check the output against C1-C15:

1. **C1** — Are all external inputs validated at the boundary?
2. **C6** — Are secrets absent from code and logs?
3. **C8** — Do any methods exceed 60 lines?
4. **C10** — Is idempotency addressed for state-changing operations?
5. **C12** — Is configuration separated from code?

If fewer than 4 of these 5 constraints are satisfied, the SKILL may not be loading correctly or may need tuning for your project context.
