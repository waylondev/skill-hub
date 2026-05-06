# Architectural Gates (MANDATORY)

## Purpose

This file defines the **mandatory architecture review gates** that AI MUST pass through BEFORE generating any code.
These are NOT suggestions — they are hard enforcement rules. If a gate fails, AI MUST redesign, NOT generate.

---

## Gate 0: Context Profile Determination

**Before any code generation**, determine the project context profile using [context-branching.md].

### Enforcement

- **If context is ambiguous**: Ask the user. Do NOT assume.
- **If no context is provided**: Default to Scale-Up — include auth, observability, resilience.

---

## Gate 1: Layer Architecture Enforcement

**CRITICAL**: This is the #1 failure mode. AI consistently violates layer boundaries.

### Mandatory Layer Structure

```
┌─────────────────────────────────────────────────────────┐
│  Presentation Layer (api/)                              │
│  - HTTP mapping (@RestController, @GetMapping)         │
│  - Input validation (@Valid)                           │
│  - Return DTOs (NOT domain objects)                    │
│  - NO business logic                                   │
│  - NO direct repository access                         │
├─────────────────────────────────────────────────────────┤
│  Service Layer (service/)                              │
│  - Business logic orchestration                        │
│  - Transaction boundaries (@Transactional)             │
│  - Return DOMAIN OBJECTS (NOT DTOs)                   │
│  - NO HTTP types                                       │
│  - DTO mapping is Controller/Mapper's job              │
├─────────────────────────────────────────────────────────┤
│  Domain Layer (domain/)                                │
│  - Aggregate roots, Value objects, Domain invariants   │
│  - NO infrastructure concerns                          │
│  - NO framework annotations                            │
├─────────────────────────────────────────────────────────┤
│  Repository Layer (repository/)                        │
│  - Data access abstraction                             │
│  - JPA queries, projections                            │
├─────────────────────────────────────────────────────────┤
│  Mapper Layer (mapper/)                                │
│  - Domain ↔ DTO conversion                             │
├─────────────────────────────────────────────────────────┤
│  Config Layer (config/)                                │
│  - Framework configuration (Security, Resilience)      │
└─────────────────────────────────────────────────────────┘
```

### Hard Rules (VIOLATION = REJECT + REDESIGN)

| Rule | Check |
|------|-------|
| Service MUST NOT return DTO | Return type of `@Service` methods |
| Controller MUST NOT return @Entity | Return type of `@RestController` methods |
| Service MUST NOT import HTTP types | No HttpServletRequest in service/ |
| Controller MUST NOT access Repository | No Repository @Autowired in Controller |
| Domain MUST NOT depend on framework | No @Service, @Autowired in domain/ |

### Read Path Exception

For list/read-heavy endpoints, Service MAY return DTO projections IF:
- The projection is a read-only data carrier (not an entity)
- A comment explains why Service returns DTO (read optimization)
- The write path (create/update/cancel) still returns domain objects

---

## Gate 2: TOCTOU Prevention Enforcement

Any pattern that checks then acts non-atomically is **PROHIBITED**.

### Required Patterns

| Pattern | When | Implementation |
|---------|------|----------------|
| Unique constraint + catch | Idempotent creation | `try { save(); } catch (DataIntegrityViolationException) { return existing; }` |
| Atomic UPSERT | PostgreSQL | `INSERT ... ON CONFLICT DO NOTHING RETURNING *` |
| SELECT ... FOR UPDATE | Inventory/balance deduction | Pessimistic lock within transaction |
| Optimistic Locking | Low-conflict updates | `@Version` field + retry |

---

## Gate 3: Idempotency Enforcement

All POST/PATCH endpoints that create or modify state **MUST** require an `Idempotency-Key` header.

### Prohibited

```java
// NO: auto-UUID defeats idempotency
String key = idempotencyKey != null ? idempotencyKey : UUID.randomUUID().toString();
```

### Required

```java
// YES: header is mandatory
@RequestHeader("Idempotency-Key") @NotBlank String idempotencyKey
```

---

## Gate 4: Security Entry Point Enforcement

All security framework error responses **MUST** use entry point handlers.

### Required

- `authenticationEntryPoint` → JSON 401
- `accessDeniedHandler` → JSON 403
- Global handler catch-all → generic 500

---

## Gate 5: Aggregate Root Invariant Enforcement

All business invariants **MUST** be enforced within the aggregate root.

### Prohibited

```java
// NO: invariant check in Service
if (order.getStatus() == CANCELLED) throw ...;
order.setStatus(CANCELLED);
```

### Required

```java
// YES: invariant in aggregate
public void cancel() {
    if (this.status == CANCELLED) throw ...;
    this.status = CANCELLED;
}
```

---

## Gate 6: Projection Query Enforcement

List/detail endpoints **MUST** use DTO projections, NOT load entities + map in Service.

### Required

```java
@Query("SELECT new com.example.dto.OrderResponse(o.id, ...) FROM Order o WHERE ...")
Page<OrderResponse> findResponses(...);
```

---

## Gate 7: Configuration Externalization

Zero hardcoded values in source code. Every environment-dependent value uses `${ENV_VAR:default}`.

### Prohibited Values

| Pattern | Why |
|---------|-----|
| `"localhost"`, `"127.0.0.1"` | Fails in production |
| `"jdbc:postgresql://db-prod:5432/..."` | Environment-specific URL |
| `"sk-prod-..."`, `"api-key-..."` | Secret in source |
| `30` (magic number timeout) | Cannot tune per environment |

---

## Gate 8: Code Correctness Enforcement

**NEW**: Generated code MUST compile and use framework APIs correctly.

### Hard Rules

| Rule | Violation Example | Correct Usage |
|------|-------------------|---------------|
| Annotations must be valid types | `@HttpStatus.CREATED` | `@ResponseStatus(HttpStatus.CREATED)` |
| Method signatures must match framework contracts | Wrong param type in `@ExceptionHandler` | Correct exception type |
| Imports must be resolvable | `import org.springframework.web.HttpRequestMethodNotSupportedException` (deprecated) | Use correct class |
| Record components must use valid types | `record X(BigDecimal)` missing import | Import `java.math.BigDecimal` |
| Enum values must be used correctly | `HttpStatus.CREATED` as annotation | `@ResponseStatus(HttpStatus.CREATED)` |
| Generic types must be specified | `List list = new ArrayList()` (raw) | `List<String> list = new ArrayList<>()` |
| Override methods must match parent signature | `doFilter(req, res, chain)` wrong types | Match `FilterChain` interface |

### Enforcement

- **AI self-check**: For every annotation, verify it's a valid annotation type (has `@` in definition)
- **AI self-check**: For every `@ExceptionHandler(X.class)`, verify X is an exception type, not an enum value

---

## Gate 9: Dependency Direction Enforcement

**NEW**: Lower layers MUST NOT depend on upper layers.

### Layer Dependency Rules

```
Controller → Service → Domain
    ↓           ↓
  Mapper    Repository
```

| Rule | Violation |
|------|-----------|
| Service MUST NOT import from api/ or api.dto/ | `import com.example.api.dto.CreateOrderRequest;` |
| Domain MUST NOT import from service/ or api/ | `import com.example.service.OrderService;` |
| Repository MUST NOT import from service/ or api/ | `import com.example.api.dto.*;` |
| Controller MUST NOT import from repository/ | `import com.example.repository.OrderRepository;` |

### Exception

Repository projection queries MAY reference DTO classes (JPQL constructor expression). This is a read optimization, not a layer dependency violation.

### Enforcement

- **AI self-check**: For every `import` in a file, verify the imported package is in an allowed lower layer
- **ArchUnit test**: `classes().that().resideInAPackage("..service..").should().onlyDependOnClassesThat().resideInAnyPackage("..domain..", "..repository..", "java..", "org.springframework..", "io.micrometer..", "lombok..")`

---

## Gate 10: Code Readability Enforcement

**NEW**: Generated code MUST be readable and idiomatic.

### Hard Rules

| Rule | Violation | Correct Usage |
|------|-----------|---------------|
| Use imports, not fully qualified names | `public com.example.api.dto.OrderResponse create(...)` | `public OrderResponse create(...)` after import |
| Consistent naming convention | Mixed `snake_case` and `camelCase` | All `camelCase` for Java |
| Method names describe intent | `public Order do(Order o)` | `public Order createOrder(OrderCommand cmd)` |
| No redundant type declarations | `Order order = Order.create(...)` | `var order = Order.create(...)` (Java 10+) |
| No magic numbers | `if (status == 2)` | `if (status == OrderStatus.CONFIRMED)` |

### Enforcement

- **AI self-check**: Scan for `com.example.` in method signatures — if found, add import instead
- **AI self-check**: Any number literal used as condition/value → flag as magic number

---

## Pre-Generation Gate Checklist

AI MUST evaluate ALL 11 gates (G0-G10) BEFORE generating code.

| Gate | Name | Check |
|------|------|-------|
| G0 | Context Profile | Determined? |
| G1 | Layer Architecture | Service returns domain objects? Controller returns DTOs? Dedicated Mapper? |
| G2 | TOCTOU Prevention | No check-then-act? Atomic patterns used? |
| G3 | Idempotency | POST requires Idempotency-Key header? No auto-UUID? |
| G4 | Security Entry Points | entry points configured? Global catch-all? |
| G5 | Aggregate Invariants | Business rules in domain objects? |
| G6 | Projection Queries | Read endpoints use DTO projections? |
| G7 | Config Externalization | Zero hardcoded values? |
| G8 | Code Correctness | All annotations valid? Method signatures correct? |
| G9 | Dependency Direction | Service doesn't import api.dto? Domain doesn't import service? |
| G10 | Code Readability | Imports used instead of FQN? No magic numbers? |

**Pass criteria**: ALL gates must pass. Any failure → redesign → re-evaluate → then generate.
