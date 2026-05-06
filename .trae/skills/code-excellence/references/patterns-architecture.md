# Architecture Patterns — Architect-Level Reference

## Purpose

This reference encodes patterns used by architects to **design systems**, not just
write code. It covers Architecture Decision Records, domain modeling, system
visualization, multi-tenancy strategies, and technical debt management.

When you need to make a system-level decision, consult this file.

---

## Pattern: Architecture Decision Record (ADR)

**Use when**: You are making a significant architectural decision that someone 2 years
from now will question. Every "why did we choose X over Y?" deserves an ADR.

**Structure**: Title → Context → Decision → Consequences (from Michael Nygard's template)

```markdown
# ADR-005: Use PostgreSQL JSONB for Flexible Product Attributes

## Status
Accepted (2026-03-15)

## Context
The product catalog has variable attributes per category (electronics have "wattage",
clothing has "size" and "material"). We need to support 200+ attribute types without
creating 200 columns. Options considered:
- EAV (Entity-Attribute-Value) pattern — standard but query performance is poor
- MongoDB for catalog — adds operational complexity (second database)
- PostgreSQL JSONB — native JSON support with indexing

## Decision
Use PostgreSQL JSONB column for product attributes with GIN index.
Use generated columns for frequently filtered attributes (price, brand).
Keep the core product table (< 20 columns) for fields shared across all categories.

## Consequences
**Positive**: Single database. Fast queries on indexed JSON paths.
Schema changes for new attributes require zero migrations.
**Negative**: JSONB queries are less readable than standard SQL.
Developers are less familiar with JSON path expressions.
**Mitigation**: Provide a thin attribute accessor API.
Document JSON path patterns for common queries.
```

**When to write an ADR**: Every time the decision-tree output is not the obvious default.
Every time context-branching changes the recommendation. Every time you choose to
violate a generation constraint with documented rationale.

---

## Pattern: C4 Model for System Visualization

**Use when**: You need to communicate system architecture at different zoom levels
to different audiences (developers, architects, stakeholders).

### Level 1: System Context (for everyone)
```
[User] → [E-Commerce Platform] → [Payment Gateway]
                                 → [Email Service]
                                 → [ERP System]
```

### Level 2: Container (for technical stakeholders)
```
[Web App: React SPA] → [API Gateway: Kong]
                     → [Order Service: Spring Boot]
                        → [PostgreSQL: Orders DB]
                        → [Kafka: order-events]
                     → [Payment Service: Spring Boot]
                        → [External: Stripe]
                     → [Notification Service: Go]
                        → [External: SendGrid]
```

### Level 3: Component (for developers)
```
Order Service:
  OrderController → OrderService → OrderRepository → PostgreSQL
                                 → OutboxRepository
                                 → PaymentClient
  OrderEventHandler ← Kafka
```

### Level 4: Code (for detailed design)
Class diagrams, sequence diagrams for critical flows.

**Rule**: Start every architecture discussion with a C4 diagram. The right level
prevents confusion between "we should use Kafka" (container-level) and "this class
needs a factory" (code-level).

---

## Pattern: Bounded Context Mapping

**Use when**: You are designing a system with multiple domains and need to define
how they interact. Essential for DDD and microservice boundaries.

### Context Relationship Patterns

| Relationship | When to Use | Example |
|-------------|-------------|---------|
| **Partnership** | Teams cooperate, both sides adapt | Order + Payment (evolve together) |
| **Shared Kernel** | Share a small, stable core model | Money, UserId, Timestamp utilities |
| **Customer-Supplier** | Upstream defines, downstream adapts | Payment is supplier, Order is customer |
| **Conformist** | Downstream must conform, no influence | Third-party API integration (Stripe) |
| **Anti-Corruption Layer** | Protect your model from external mess | Legacy ERP → ACL → Clean Payment Model |
| **Open Host Service** | Provide a well-defined, multi-consumer API | Payment API with REST + gRPC + events |
| **Published Language** | Standard format all contexts use | CloudEvents, AsyncAPI, Protobuf schemas |
| **Separate Ways** | No integration needed, don't force it | Recommendation engine (standalone) |

```java
// Anti-Corruption Layer example
// Legacy ERP returns: { "ORD_ID": 123, "ORD_STAT_CD": "C", "CUST_NM": "..." }
// Our domain uses: OrderCancelledEvent(orderId=123)

@Component
public class ErpAntiCorruptionLayer {
    public OrderCancelledEvent translate(ErpMessage raw) {
        // Translate. Validate. Filter. Cleanse.
        if (!"ORDER_CANCEL".equals(raw.type())) return null; // ignore irrelevant
        var orderId = parseOrderId(raw.payload().get("ORD_ID"));
        if (orderId == null) { metrics.invalidMessage.increment(); return null; }
        return new OrderCancelledEvent(orderId);
    }
    // Our domain NEVER sees ERP's field names, status codes, or structure.
}
```

---

## Pattern: Multi-Tenancy Architecture

**Use when**: Your application serves multiple customers (tenants) with data isolation
requirements. Common in SaaS products.

### Isolation Strategies — Choose ONE per bounded context

| Strategy | Isolation | Cost | Complexity | When to Use |
|----------|-----------|------|-----------|-------------|
| **Database per Tenant** | Strongest | Highest | Low (ops: high) | Enterprise, compliance-heavy (HIPAA, SOC2) |
| **Schema per Tenant** | Strong | Medium | Medium | PostgreSQL's native schema feature |
| **Row-Level (tenant_id column)** | Weakest | Lowest | Medium (app-level) | B2C, multi-tenant-lite, early-stage SaaS |
| **Hybrid** | Segmented | Medium | High | Platinum tenants get dedicated DB, others share |

```java
// Row-level isolation with automatic tenant_id injection
@Component
public class TenantContext {
    private static final ThreadLocal<Long> currentTenant = new ThreadLocal<>();

    public static void set(Long tenantId) { currentTenant.set(tenantId); }
    public static Long get() { return currentTenant.get(); }
    public static void clear() { currentTenant.remove(); }
}

// Hibernate filter automatically scopes ALL queries
@FilterDef(name = "tenantFilter", parameters = @ParamDef(name = "tenantId", type = Long.class))
@Filter(name = "tenantFilter", condition = "tenant_id = :tenantId")
@Entity
public class Order {
    private Long tenantId;
    // ALL queries: WHERE tenant_id = :tenantId — automatic, cannot forget
}

// Filter activated per request
@WebFilter
public class TenantFilter implements Filter {
    public void doFilter(ServletRequest req, ServletResponse res, FilterChain chain) {
        var tenantId = extractTenantFromJwtOrSubdomain(req);
        TenantContext.set(tenantId);

        // Activate Hibernate filter for this session
        var session = em.unwrap(Session.class);
        session.enableFilter("tenantFilter").setParameter("tenantId", tenantId);

        try { chain.doFilter(req, res); }
        finally { TenantContext.clear(); }
    }
}
```

---

## Pattern: Technical Debt Quantification

**Use when**: You see a short-cut in code and need to quantify its long-term cost
to justify refactoring. Transforms "this code is bad" into "this code costs $X/month".

### Debt Quadrant (Martin Fowler)

```
           | Reckless       | Prudent
-----------+----------------+----------------
Deliberate | "We don't      | "We must ship
           | have time for  | now and deal
           | design"        | with debt later"
-----------+----------------+----------------
Inadvertent| "We don't      | "Now we know
           | know any       | how we should
           | better"        | have built it"
```

### Debt Calculation Formula

```
Monthly Debt Cost = (Extra Development Hours per Change × Changes per Month × Hourly Rate)
                  + (Production Incidents Caused × MTTR Hours × Hourly Rate)
                  + (Onboarding Time Delta × New Hires per Year / 12 × Hourly Rate)

Example:
  God Service (AP-1): Every change touches 3 extra hours of coordination
  10 changes/month × 3hrs × $100/hr = $3,000/month in coordination alone

  Missing Idempotency (AP-8): 2 double-charge incidents/month
  2 incidents × 4hrs resolution × $100/hr = $800/month + refund costs + reputational damage
```

### Repayment Strategy

- **> 10% of sprint capacity** on debt → schedule repayment sprint
- **Debt cost > feature cost** in affected module → stop features, pay debt first
- **Debt causing incidents** → fix immediately (Constrain 2: Correctness > everything)
- **Document ALL deliberate debt** as an ADR with planned repayment date

---

## Pattern: Evolvability — Fitness Functions

**Use when**: You want automated, continuous verification that the system's
architectural qualities are not degrading.

```java
// ArchUnit — architectural fitness function
@Test
void domainLayerDoesNotDependOnInfrastructure() {
    noClasses()
        .that().resideInAPackage("..domain..")
        .should().dependOnClassesThat().resideInAPackage("..infrastructure..")
        .because("Domain must be pure — no framework, no database dependencies")
        .check(classes);
}

@Test
void servicesArePackagePrivate() {
    classes()
        .that().haveSimpleNameEndingWith("Service")
        .should().bePackagePrivate()
        .because("Services are internal — only API module exposes public contracts")
        .check(classes);
}

@Test
void noCyclicDependencies() {
    slices()
        .matching("com.example.(*)..")
        .should().beFreeOfCycles()
        .check(classes);
}

@Test
void noRepositoryInController() {
    noClasses()
        .that().resideInAPackage("..controller..")
        .should().dependOnClassesThat().resideInAPackage("..repository..")
        .because("Controller → Service ONLY. Repository bypass is forbidden.")
        .check(classes);
}
```

**Fitness function categories**:
- **Structural**: Package dependencies, layering, cyclic checks
- **Naming**: Class/method naming conventions enforced
- **Quality**: Max method length, max parameter count, code duplication thresholds
- **Security**: No JWT secrets in code, no println in production code
- **Observability**: Every service has health check, every controller has metrics

---

## Pattern: Expansion-Contract (Zero-Downtime Migration)

**Use when**: Database schema changes on a live system with zero downtime.

```
Phase 1: EXPAND — Add new schema, code supports both old and new
Phase 2: MIGRATE — Backfill data at low-traffic time
Phase 3: CONTRACT — Remove old schema, code uses only new
```

```sql
-- EXPAND: Add new column with NULL allowed (no rewrite, instant in PostgreSQL)
ALTER TABLE orders ADD COLUMN tracking_number TEXT;

-- Code now writes to BOTH old and new columns
-- Code reads from new (with fallback to old for rows not yet migrated)

-- MIGRATE: Batch-backfill existing rows
UPDATE orders SET tracking_number = old_tracking_code
WHERE tracking_number IS NULL AND old_tracking_code IS NOT NULL;

-- Code reads only from new (all rows migrated)

-- CONTRACT: Drop old column
ALTER TABLE orders DROP COLUMN old_tracking_code;
```

```java
// Code during EXPAND phase — read from new, fallback to old
public Optional<String> getTrackingNumber(Long orderId) {
    var order = orderRepo.findById(orderId).orElseThrow();
    return Optional.ofNullable(order.getTrackingNumber())
        .or(() -> Optional.ofNullable(order.getLegacyTrackingCode()));
}

// Code during CONTRACT phase — only new
public Optional<String> getTrackingNumber(Long orderId) {
    return Optional.ofNullable(orderRepo.findById(orderId).orElseThrow().getTrackingNumber());
}
```

---

## Pattern: Modular Monolith Structure

**Use when**: You want microservice-like boundaries without operational complexity.

```
com.example
├── orders/
│   ├── api/           // Public contract — OrderDto, OrderService interface
│   ├── domain/        // Internal — Order, OrderRepository
│   └── infra/         // Internal — JpaOrderRepository
├── payments/
│   ├── api/           // Public — PaymentDto
│   ├── domain/        // Internal
│   └── infra/         // Internal
├── notifications/
│   ├── api/           // Public
│   ├── domain/        // Internal
│   └── infra/         // Internal
└── shared/
    ├── kernel/        // Money, UserId, Timestamp — Shared Kernel
    └── events/        // CloudEvents base type
```

**Module rules**:
- `api/` packages are the ONLY public API. Everything else is package-private.
- A module can only depend on `api/` of other modules, never on `domain/` or `infra/`.
- Inter-module communication: API calls (sync) or events (async). Never direct DB access.
- Module boundaries enforced by ArchUnit tests (Fitness Functions).

---

## Quick Architecture Checklist

Before approving system design:

- [ ] ADR written for every major technology choice?
- [ ] C4 Container diagram exists and is up to date?
- [ ] Bounded contexts identified with explicit relationship types?
- [ ] Multi-tenancy strategy chosen and documented?
- [ ] Technical debt quantified for known shortcuts?
- [ ] Fitness functions (ArchUnit) checking structural rules?
- [ ] Zero-downtime migration strategy for schema changes?
- [ ] Module boundaries aligned with business capabilities?
- [ ] Cross-module dependency direction is clear and acyclic?
- [ ] Shared kernel is minimal and stable (no churn)?
