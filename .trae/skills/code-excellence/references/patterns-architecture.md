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

## Pattern: Event Schema Evolution

**Use when**: Your system uses event-driven architecture with Kafka, Pulsar, or Kinesis, and you need to evolve event schemas without breaking consumers or producers.

### Avro/Protobuf Compatibility Rules

Schema registries enforce three compatibility levels. Choose one per topic/stream and never change it without a migration plan.

| Compatibility | Definition | Producer | Consumer | When to Use |
|--------------|-----------|----------|----------|-------------|
| **Backward** | New schema can read data written by old schema | Can upgrade first | Must upgrade first | Most common — consumers read old events with new code |
| **Forward** | Old schema can read data written by new schema | Must upgrade first | Can upgrade first | When producers roll out faster than consumers |
| **Full** | Both backward and forward | Any order | Any order | Ideal but restrictive — requires defaults on all new fields |

**Rule**: Default to **Backward** compatibility. It allows consumer-first deployment: deploy new consumer code, then deploy new producer code.

```avro
// Schema v1 — initial order event
{
  "type": "record",
  "name": "OrderCreated",
  "namespace": "com.example.events",
  "fields": [
    { "name": "orderId", "type": "string" },
    { "name": "amount", "type": "double" },
    { "name": "currency", "type": "string" }
  ]
}

// Schema v2 — BACKWARD compatible (new optional field with default)
// Old consumers ignore "customerId". New consumers read old events and get default null.
{
  "type": "record",
  "name": "OrderCreated",
  "namespace": "com.example.events",
  "fields": [
    { "name": "orderId", "type": "string" },
    { "name": "amount", "type": "double" },
    { "name": "currency", "type": "string" },
    { "name": "customerId", "type": ["null", "string"], "default": null }
  ]
}

// Schema v3 — NOT backward compatible (new required field without default)
// Old consumers fail to read events written with v3. NEVER do this on a live topic.
{
  "type": "record",
  "name": "OrderCreated",
  "namespace": "com.example.events",
  "fields": [
    { "name": "orderId", "type": "string" },
    { "name": "amount", "type": "double" },
    { "name": "currency", "type": "string" },
    { "name": "customerId", "type": "string" }  // FAILS: no default
  ]
}
```

**Expert note**: Avro's compatibility check is binary: it compares the new schema against the *latest registered* schema by default. Enable `BACKWARD_TRANSITIVE` to validate against *all* previous schema versions — essential for topics with long retention where consumers may lag by multiple versions.

```java
// Confluent Schema Registry client — register with explicit compatibility
var schemaRegistryClient = new CachedSchemaRegistryClient("http://schema-registry:8081", 100);

// Register backward-compatible schema
var parser = new Schema.Parser();
var schemaV2 = parser.parse("""
    {"type":"record","name":"OrderCreated","namespace":"com.example.events",
     "fields":[
       {"name":"orderId","type":"string"},
       {"name":"amount","type":"double"},
       {"name":"currency","type":"string"},
       {"name":"customerId","type":["null","string"],"default":null}
     ]}
    """);

// This throws SchemaRegistryException if incompatible
schemaRegistryClient.register("order-events-value", schemaV2);

// Verify compatibility explicitly before registering
boolean isCompatible = schemaRegistryClient.testCompatibility(
    "order-events-value", schemaV2);
if (!isCompatible) {
    throw new IllegalStateException("Schema breaks compatibility — abort deployment");
}
```

### Schema Registry Usage Patterns

**Confluent Schema Registry**

```java
// Producer with AvroSerializer — schema auto-registered on first send
Properties props = new Properties();
props.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, "kafka:9092");
props.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, StringSerializer.class);
props.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, KafkaAvroSerializer.class);
props.put("schema.registry.url", "http://schema-registry:8081");
// CRITICAL: Prevent auto-registration of breaking changes in production
props.put("auto.register.schemas", false);
props.put("use.latest.version", true); // Use latest registered schema

KafkaProducer<String, OrderCreated> producer = new KafkaProducer<>(props);
```

**AWS Glue Schema Registry**

```java
// GlueSchemaRegistryKafkaSerializer — same pattern, different backend
Properties props = new Properties();
props.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, "kafka:9092");
props.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, StringSerializer.class);
props.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG,
    GlueSchemaRegistryKafkaSerializer.class.getName());
props.put(AWSSchemaRegistryConstants.AWS_REGION, "us-east-1");
props.put(AWSSchemaRegistryConstants.REGISTRY_NAME, "production-events");
props.put(AWSSchemaRegistryConstants.SCHEMA_NAME, "OrderCreated");
props.put(AWSSchemaRegistryConstants.COMPATIBILITY_SETTING,
    Compatibility.BACKWARD.name()); // Enforced at registry level

KafkaProducer<String, OrderCreated> producer = new KafkaProducer<>(props);
```

**Rule**: Always set `auto.register.schemas=false` in production. Schema registration must be an explicit CI/CD step with compatibility checks, not a runtime side effect.

### Backward-Compatible Field Change Strategies

| Change | Safe? | Strategy | Example |
|--------|-------|----------|---------|
| **Add field** | Yes | Add with `default` value (or union with null) | `"default": null` |
| **Deprecate field** | Yes | Stop writing, keep in schema, document deprecated | `@Deprecated` in generated code |
| **Rename field** | No (alone) | Use aliases in Avro, or add new + deprecate old | `"aliases": ["oldName"]` |
| **Change type** | No | Add new field with new type, deprecate old | `amountDecimal` replaces `amount: double` |
| **Remove field** | No | Deprecate first, remove only after ALL consumers upgraded | Plan 2+ release cycles |

```avro
// Renaming with alias — old consumers reading old data still work
{
  "name": "customerIdentifier",
  "type": "string",
  "aliases": ["customerId"]  // Avro resolves "customerId" to this field
}
```

```java
// Deprecation strategy in generated code + consumer logic
@Deprecated
public CharSequence getLegacyStatusCode() { ... }

public CharSequence getStatus() { ... }

// Consumer handles both during transition period
public OrderStatus parseStatus(OrderCreatedEvent event) {
    if (event.getStatus() != null) {
        return OrderStatus.valueOf(event.getStatus().toString());
    }
    // Fallback to deprecated field for old events
    return legacyStatusMap.get(event.getLegacyStatusCode().toString());
}
```

**Expert note**: The Expansion-Contract pattern applies to schemas too. Phase 1: add new field (expand). Phase 2: migrate all producers to write new field. Phase 3: remove old field (contract). Never compress phases on high-volume topics.

### Event Catalog Management

An Event Catalog is the single source of truth for event discovery, ownership, and contracts. Without it, teams duplicate events, break contracts unknowingly, and lose track of consumers.

**Required metadata per event**:

```yaml
# event-catalog/order-created.yaml
name: OrderCreated
namespace: com.example.orders
owner: team-orders@example.com
schemaVersion: "2.1.0"
compatibility: BACKWARD
topic: order-events
partitionKey: orderId

consumers:
  - team-payments@example.com
  - team-analytics@example.com
  - team-fulfillment@example.com

changelog:
  - version: "1.0.0"
    date: 2025-01-15
    changes: Initial schema
  - version: "2.0.0"
    date: 2025-04-10
    changes: Added customerId field (nullable)
  - version: "2.1.0"
    date: 2025-06-20
    changes: Deprecated legacyStatusCode, added status enum

deprecatedFields:
  - name: legacyStatusCode
    deprecatedSince: "2.1.0"
    removalPlanned: "2025-12-01"
```

**Rule**: Every event type MUST have an owner team and a documented consumer list. The owner approves all schema changes and notifies consumers before deployment.

**Documentation standards**:
- AsyncAPI specification for every async API (events, WebSockets)
- Example payload for every schema version
- Error scenarios: what happens if a required field is malformed
- Retry semantics: at-least-once, exactly-once, or at-most-once

```java
// AsyncAPI-driven code generation (Spring Cloud Contract style)
// The AsyncAPI spec becomes the contract test
@ContractTest
public class OrderCreatedContractTest {
    @Test
    public void orderCreatedEventMatchesAsyncApiSchema() {
        var event = OrderCreated.newBuilder()
            .setOrderId("ORD-123")
            .setAmount(99.99)
            .setCurrency("USD")
            .setCustomerId("CUST-456")
            .build();

        // Validates against the AsyncAPI schema registered in the catalog
        AsyncApiValidator.assertValid("order-created", event.toString());
    }
}
```

### Common Schema Evolution Anti-Patterns

**Anti-Pattern 1: Breaking changes without versioning**

```avro
// WRONG: Changing type in-place without version bump
// v1: { "name": "amount", "type": "double" }
// v2 (ILLEGAL): { "name": "amount", "type": "string" }  // Breaks ALL consumers
```

**Fix**: Add a new field (`amountDecimal: string`), deprecate old, remove after migration.

**Anti-Pattern 2: Incompatible type changes via union tricks**

```avro
// WRONG: Union order matters in Avro. This is NOT backward compatible.
// Old: { "name": "value", "type": "long" }
// New: { "name": "value", "type": ["null", "long", "string"] }  // FAILS
```

**Fix**: Avro readers use the schema's union index. Adding types before existing ones shifts indices and corrupts deserialization. Only append new types to the END of unions.

**Anti-Pattern 3: Missing default values on new fields**

```avro
// WRONG: New required field without default — old consumers cannot read new events
{ "name": "taxAmount", "type": "double" }  // FAILS backward compatibility
```

**Fix**: Always provide defaults. If no sensible default exists, use a union with null and default to null.

```avro
// CORRECT
{ "name": "taxAmount", "type": ["null", "double"], "default": null }
```

**Anti-Pattern 4: Silent schema auto-registration in production**

```java
// WRONG: Default auto.register.schemas=true lets any producer push breaking changes
props.put("auto.register.schemas", true);  // DANGEROUS in production
```

**Fix**: Disable auto-registration. Use CI/CD pipelines with `maven-avro-plugin` or `gradle-avro-plugin` to register schemas explicitly after compatibility checks pass.

**Anti-Pattern 5: Removing a field before all consumers upgrade**

```avro
// WRONG: Removing "legacyStatusCode" while team-erp still reads it
{ "name": "status", "type": "string" }
// legacyStatusCode removed — team-erp consumer crashes on deserialization
```

**Fix**: Maintain a consumer lag dashboard. Remove fields only when consumer offsets for ALL consumer groups have passed the last event containing the old field, OR after a published deprecation timeline (minimum 2 release cycles).

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

---

## Pattern: Saga Orchestration vs Choreography

**Use when**: You need to coordinate a multi-step distributed transaction. Choose between orchestration (central coordinator) and choreography (event-driven decentralized) based on complexity.

### Decision Guide

| Signal | Orchestration | Choreography |
|--------|--------------|--------------|
| Steps | > 4 steps or conditional branching | ≤ 4 linear steps |
| Visibility | Need single view of saga state | Each step manages own state |
| Coupling | Prefer loose coupling between steps | Steps know about each other via events |
| Complexity | Complex error recovery, retries, timeouts | Simple compensation (undo last step) |
| Debugging | Centralized saga log | Distributed tracing required |

### Orchestration Pattern (Centralized Coordinator)

```java
// Saga orchestrator — manages the entire flow
@Component
public class OrderSagaOrchestrator {
    private final InventoryService inventory;
    private final PaymentService payment;
    private final ShippingService shipping;
    private final SagaStateRepository sagaStateRepo;

    @Transactional
    public SagaResult execute(OrderId orderId) {
        var saga = sagaStateRepo.findById(orderId).orElse(new OrderSaga(orderId));

        try {
            if (saga.isStepPending(RESERVE_INVENTORY)) {
                inventory.reserve(orderId, saga.getItems());
                saga.advanceTo(PAYMENT);
                sagaStateRepo.save(saga);
            }

            if (saga.isStepPending(PAYMENT)) {
                payment.capture(orderId, saga.getTotal());
                saga.advanceTo(SHIPPING);
                sagaStateRepo.save(saga);
            }

            if (saga.isStepPending(SHIPPING)) {
                shipping.createDelivery(orderId, saga.getAddress());
                saga.complete();
                sagaStateRepo.save(saga);
                return SagaResult.success(orderId);
            }

        } catch (Exception e) {
            compensate(saga, e);
            sagaStateRepo.save(saga);
            return SagaResult.failure(orderId, e.getMessage());
        }
    }

    private void compensate(OrderSaga saga, Exception cause) {
        // Compensate in reverse order
        if (saga.isStepCompleted(SHIPPING)) shipping.cancel(saga.getOrderId());
        if (saga.isStepCompleted(PAYMENT)) payment.refund(saga.getOrderId());
        if (saga.isStepCompleted(RESERVE_INVENTORY)) inventory.release(saga.getOrderId());
        saga.failed(cause.getMessage());
    }
}
```

### Choreography Pattern (Event-Driven Decentralized)

```java
// Each step reacts to events — no central coordinator
@Component
public class PaymentSagaStep {
    private final PaymentService payment;
    private final DomainEventPublisher publisher;

    @EventListener
    @Transactional
    public void on(InventoryReservedEvent e) {
        try {
            payment.capture(e.orderId(), e.total());
            publisher.publish(new PaymentCapturedEvent(e.orderId(), e.total()));
        } catch (PaymentException ex) {
            publisher.publish(new PaymentFailedEvent(e.orderId(), ex.getMessage()));
        }
    }

    @EventListener
    public void on(OrderSagaFailedEvent e) {
        if (e.failedAt() != PAYMENT) return;
        payment.refund(e.orderId()); // compensate
    }
}
```

**Expert note**: Start with **orchestration** for business-critical sagas. The centralized state provides auditability and simplifies debugging. Reserve choreography for simple, well-understood flows where adding an orchestrator feels like over-engineering.

---

## Pattern: Distributed Data Consistency

**Use when**: Data spans multiple services or databases and you need to maintain consistency without distributed transactions.

### Consistency Spectrum

| Approach | Consistency | Latency | Complexity | When to Use |
|----------|------------|---------|-----------|-------------|
| **2PC/XA** | Strong | High | Low (framework handles) | Legacy systems, single vendor, non-performance-critical |
| **Saga** | Eventual | Medium | Medium | Multi-service transactions |
| **Outbox + CDC** | Eventual (low lag) | Low-Medium | Medium | Event sourcing, audit trails |
| **Compensating Write** | Eventual | Low | High (custom logic) | High-throughput, tolerant of temporary inconsistency |

### Outbox + CDC Pattern (Debezium)

```sql
-- Outbox table — same transaction as business data
CREATE TABLE outbox_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    aggregate_type VARCHAR(255) NOT NULL,
    aggregate_id VARCHAR(255) NOT NULL,
    event_type VARCHAR(255) NOT NULL,
    payload JSONB NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    -- Debezium uses this to route to Kafka topics
    INDEX idx_aggregate (aggregate_type, aggregate_id)
);
```

```java
// Same transaction — data + event
@Transactional
public void approveOrder(Long orderId) {
    var order = orderRepo.findById(orderId).orElseThrow();
    order.approve();
    orderRepo.save(order);

    // Insert event in same DB transaction
    outboxRepo.save(new OutboxEvent(
        "Order", orderId.toString(), "OrderApproved",
        Json.toJson(new OrderApprovedPayload(orderId, order.total()))
    ));
    // Debezium CDC connector picks this up from WAL and publishes to Kafka
    // No dual-write problem — if transaction rolls back, event is too
}
```

**Rule**: Never write to a database AND publish to Kafka in separate steps. The Outbox + CDC pattern is the only guaranteed-at-least-once approach without 2PC.

---

## Pattern: Idempotent Consumer

**Use when**: Receiving messages from a queue that may deliver duplicates (at-least-once delivery). Every consumer must handle duplicate messages safely.

```java
@Component
public class OrderEventHandler {
    private final MessageProcessedRepository processedRepo;
    private final OrderService orderService;

    @KafkaListener(topics = "order-events")
    @Transactional
    public void handle(OrderEvent event, @Header("kafka_receivedMessageId") String messageId) {
        // Idempotency check — skip if already processed
        if (processedRepo.existsById(messageId)) {
            log.info("Duplicate event {} already processed, skipping", messageId);
            return;
        }

        orderService.process(event);
        processedRepo.save(new ProcessedMessage(messageId, Instant.now()));
    }
}
```

**Expert note**: The `messageId` check AND the business processing MUST be in the same database transaction. Otherwise, a crash between check and save causes double processing.

---

## Pattern: API Gateway vs BFF (Backend for Frontend)

**Use when**: Designing the entry point for client applications.

### Decision Guide

| Signal | API Gateway | BFF |
|--------|------------|-----|
| Clients | Multiple diverse clients (web, mobile, partner) | One specific client type |
| Routing | Route to many backend services | Aggregate data from multiple services |
| Transformation | Protocol translation, auth, rate limiting | Client-specific data shaping |
| Ownership | Platform team | Client-facing team |

### BFF Pattern

```java
// BFF for web app — aggregates data from multiple services
@RestController
@RequestMapping("/bff/web")
public class WebBffController {
    private final OrderClient orderClient;
    private final UserClient userClient;
    private final RecommendationClient recommendationClient;

    @GetMapping("/dashboard/{userId}")
    public WebDashboardResponse getDashboard(@PathVariable Long userId) {
        // Parallel fetch from multiple services
        var userFuture = userClient.getUserAsync(userId);
        var ordersFuture = orderClient.getRecentOrdersAsync(userId, 5);
        var recsFuture = recommendationClient.getForUserAsync(userId);

        CompletableFuture.allOf(userFuture, ordersFuture, recsFuture).join();

        return new WebDashboardResponse(
            userFuture.join(),
            ordersFuture.join(),
            recsFuture.join()
        );
    }
}
```

**Rule**: The BFF is owned by the frontend team and shaped by frontend needs. It changes when the UI changes. Backend services change when business logic changes. These are separate release cadences.

---

## Pattern: Graceful Degradation

**Use when**: A dependency fails and you need to keep the system partially functional rather than fully unavailable.

```java
@Component
public class ProductCatalogService {
    private final ProductRepository repo;
    private final CacheManager cache;
    private final RecommendationService recommendations;

    public ProductDetailPage getProductPage(Long productId) {
        var product = repo.findById(productId).orElseThrow();

        // Recommendations may fail — degrade gracefully
        List<Product> recommendations;
        try {
            recommendations = recommendations.getForProduct(productId);
        } catch (Exception e) {
            metrics.recommendationFailure.increment();
            log.warn("Recommendations unavailable for product {}, returning without them", productId);
            recommendations = List.of(); // empty list — page still works
        }

        // Reviews — try cache first, then DB
        var reviews = cache.getReviews(productId)
            .orElseGet(() -> repo.findReviews(productId, limit = 10));

        return new ProductDetailPage(product, reviews, recommendations);
    }
}
```

**Degradation Levels**:

| Level | Strategy | Example |
|-------|----------|---------|
| **Full** | All dependencies available | Complete product page with recommendations, reviews, related items |
| **Partial** | Non-critical dependency failed | Product page without recommendations |
| **Minimal** | Only core data available | Product name, price, image — cached from last successful fetch |
| **Static** | All dynamic systems down | "Service unavailable" with static HTML, cached product catalog |

---

## Quick Architecture Checklist (Extended)

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
- [ ] Saga uses orchestration for complex flows, choreography for simple flows?
- [ ] Outbox + CDC used for atomic event publishing?
- [ ] Consumers are idempotent (handles duplicate messages)?
- [ ] Graceful degradation paths defined for each dependency?
- [ ] BFF separates client-specific logic from backend services?
