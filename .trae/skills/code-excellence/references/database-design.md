# Database Design Patterns — Architect-Level Reference

## Purpose

Production-grade database design patterns that every architect must apply to data access layers.
Covers indexing, read/write splitting, connection pooling, query optimization, and schema migration.

---

## DP-1: Index Strategy

**Use when**: Designing or reviewing database schema, troubleshooting slow queries, or when query patterns are known.

### ❌ Wrong — Missing Indexes, Wrong Index Types

```java
@Entity
@Table(name = "orders")
public class Order {
    @Id private Long id;
    private String status;        // frequently filtered, no index
    private Long userId;          // frequently filtered, no index
    private LocalDateTime createdAt; // range queries, no index
    @Column(columnDefinition = "JSONB")
    private String attributes;    // JSONB without GIN index
}
```

```sql
SELECT * FROM orders WHERE status = 'PENDING' AND user_id = 123
ORDER BY created_at DESC LIMIT 50;
-- Seq Scan on orders (cost=0.00..50000.00) rows=50000 — TABLE SCAN
```

### Root Cause

Missing indexes force full table scans. Wrong index types (e.g., B-Tree on JSONB) provide no benefit. Without understanding selectivity, indexes are either missing or worthless.

### ✅ Expert Fix

```java
@Entity
@Table(name = "orders", indexes = {
    @Index(name = "idx_orders_status_created", columnList = "status, created_at DESC"),
    @Index(name = "idx_orders_user_status", columnList = "user_id, status")
})
public class Order {
    @Id private Long id;
    @Column(nullable = false, length = 20) private String status;
    @Column(nullable = false) private Long userId;
    @Column(nullable = false) private LocalDateTime createdAt;
}
```

```sql
-- GIN index for JSONB queries
CREATE INDEX idx_orders_attrs_gin ON orders USING GIN (attributes jsonb_path_ops);

-- Partial index for hot status only
CREATE INDEX idx_orders_pending ON orders (created_at)
WHERE status = 'PENDING';

-- After indexing:
-- Index Scan using idx_orders_user_status on orders (cost=0.29..8.31 rows=2)
```

**Index Selection Guide:**

| Data Type / Query Pattern | Index Type | Example |
|---|---|---|
| Equality (`=`, `IN`) | B-Tree (default) | `WHERE status = 'PAID'` |
| Range (`>`, `<`, `BETWEEN`) | B-Tree | `WHERE created_at > '2026-01-01'` |
| Full-text search | GIN | `WHERE content @@ 'keyword'` |
| JSONB path queries | GIN | `WHERE attributes @> '{"color":"red"}'` |
| Prefix match (`LIKE 'abc%'`) | B-Tree | `WHERE name LIKE 'John%'` |
| Geometric / KNN | GiST | `WHERE location <-> point < 1000` |

**Selectivity Calculation**: `selectivity = distinct_values / total_rows`. Index only if selectivity < 5-10% for B-Tree. High selectivity → table scan is faster.

**Expert Note**: Composite index column order matters — put high-selectivity columns first. Avoid indexes on low-cardinality columns (< 100 distinct values). Monitor unused indexes (`pg_stat_user_indexes`) and drop them.

---

## DP-2: Read/Write Splitting

**Use when**: Read volume significantly exceeds writes (> 80% reads), or when reporting/analytics queries compete with OLTP operations.

### ❌ Wrong — Single Datasource for Everything

```java
@Configuration
public class DataSourceConfig {
    @Bean
    @Primary
    public DataSource dataSource() {
        return DataSourceBuilder.create()
            .url("jdbc:postgresql://primary:5432/orders")
            .build();
    }
    // All reads AND writes hit primary. Reporting queries kill production.
}
```

### Root Cause

Without read/write splitting, heavy reads (reports, dashboard queries) consume connections and CPU on the primary, blocking writes. The entire application is bottlenecked by a single database instance.

### ✅ Expert Fix

```java
@Configuration
public class ReadWriteDataSourceConfig {

    @Bean
    @Primary
    public DataSource dataSource(
            @Qualifier("writeDataSource") DataSource writeDs,
            @Qualifier("readDataSource") DataSource readDs) {
        return new ReadWriteRoutingDataSource(writeDs, readDs);
    }

    @Bean
    @ConfigurationProperties("spring.datasource.write")
    public DataSource writeDataSource() {
        return DataSourceBuilder.create().build();
    }

    @Bean
    @ConfigurationProperties("spring.datasource.read")
    public DataSource readDataSource() {
        return DataSourceBuilder.create().build();
    }
}

public class ReadWriteRoutingDataSource extends AbstractRoutingDataSource {
    public ReadWriteRoutingDataSource(DataSource write, DataSource read) {
        Map<Object, Object> targets = Map.of(
            DataSourceType.WRITE, write,
            DataSourceType.READ, read
        );
        setTargetDataSources(targets);
        setDefaultTargetDataSource(write); // DEFAULT: write — safe by default
    }

    @Override
    protected Object determineCurrentLookupKey() {
        return TransactionSynchronizationManager.isCurrentTransactionReadOnly()
            ? DataSourceType.READ
            : DataSourceType.WRITE;
    }
}

// Service layer: annotate read-only methods
@Transactional(readOnly = true)
public List<Order> findUserOrders(Long userId) {
    return orderRepo.findByUserId(userId); // routed to READ replica
}

@Transactional
public Order create(OrderRequest req) {    // no readOnly → WRITE
    return orderRepo.save(Order.from(req));
}
```

```yaml
spring:
  datasource:
    write:
      url: jdbc:postgresql://primary.db:5432/orders
      hikari:
        maximum-pool-size: 20
    read:
      url: jdbc:postgresql://replica.db:5432/orders
      hikari:
        maximum-pool-size: 40
        read-only: true
```

**Read-After-Write Consistency**: If the caller needs to read their own write immediately, use `@Transactional` (no readOnly) for that specific flow. For user-facing pages, accept eventual consistency with small replication lag (< 100ms typical).

**Expert Note**: Read/write splitting via `AbstractRoutingDataSource` is transparent to business code. Mark all query methods `@Transactional(readOnly = true)` — it's not just documentation, it's the routing key. Default to WRITE if uncertain (SAFE by default).

---

## DP-3: Connection Pool Management

**Use when**: Configuring HikariCP, investigating connection leaks, or sizing pools for production.

### ❌ Wrong — Default or Misconfigured Pool

```yaml
spring:
  datasource:
    hikari:
      maximum-pool-size: 10 # default, too small for anything
      # connection-timeout not set → default 30s
      # idle-timeout not set → default 600s
      # leak-detection-threshold not set → no leak detection
```

### Root Cause

Default pool sizes are for development. Default timeouts mask problems. Without leak detection, a leaked connection silently reduces available pool capacity until exhaustion.

### ✅ Expert Fix

```yaml
spring:
  datasource:
    hikari:
      maximum-pool-size: 20                # formula: (core_count * 2) + effective_spindle_count
      minimum-idle: 5                      # maintain warm connections
      connection-timeout: 3000             # 3s — fail fast, don't hang
      idle-timeout: 600000                 # 10 min, must be < server-side timeout
      max-lifetime: 1800000                # 30 min — recycle before server-side limit
      leak-detection-threshold: 10000      # 10s — log leaked connection stack trace
      validation-timeout: 3000             # 3s connection test timeout
      connection-test-query: "SELECT 1"    # lightweight validation
```

**Pool Size Formula:**
```
pool_size = Tn × (Cm - 1) + 1

Where:
  Tn = max thread count (Tomcat default: 200, WebFlux: N/A)
  Cm = max simultaneous connections a single thread holds (typically 1)

So: pool_size = 200 × (1 - 1) + 1 = 1 ... WRONG!

Better formula:
  connections = ((core_count * 2) + effective_spindle_count)
  For cloud DB with SSD: core_count * 2 is sufficient.
```

**Connection Leak Detection:** Enable in non-prod always:

```java
// Code that leaks — connection never closed
public void badCode(DataSource ds) {
    var conn = ds.getConnection(); // acquired but never returned
    // ... exception occurs, conn leaked
}

// ✅ Always try-with-resources
public void goodCode(DataSource ds) {
    try (var conn = ds.getConnection()) {
        // ... conn auto-closed
    }
}
```

**Expert Note**: A connection pool that is too large is worse than one that is too small — it wastes database server memory and increases context switching. Monitor `HikariCP_active_connections` and `HikariCP_pending_connections` metrics. If pending > 0 for more than brief spikes, increase pool or add read replicas.

---

## DP-4: Query Optimization

**Use when**: API latency SLAs are violated, slow query logs show consistent patterns, or before deploying new data access code.

### ❌ Wrong — Query Without Optimization Awareness

```java
@Repository
public interface OrderRepository extends JpaRepository<Order, Long> {

    // N+1: each order triggers a separate payment query
    List<Order> findByStatus(Status status);

    // No limit — retrieves all 10M rows
    List<Order> findByUserId(Long userId);

    // Complex query using derived method name — unoptimizable
    List<Order> findByUserIdAndStatusAndCreatedAtAfterAndTotalAmountGreaterThan(
        Long userId, Status status, LocalDateTime since, Money min);
}
```

```sql
-- Generated by JPA: no LIMIT, no index hint
SELECT o.* FROM orders o WHERE o.user_id = ?;
-- Seq Scan on orders — 2.3s for 500K rows, all discarded after 20 shown
```

### Root Cause

ORM convenience methods hide query cost. Without `EXPLAIN ANALYZE` awareness, developers write queries that "work on small data" but collapse at production scale. Missing `LIMIT`, missing JOIN FETCH, missing index awareness.

### ✅ Expert Fix

```java
@Repository
public interface OrderRepository extends JpaRepository<Order, Long> {

    @Query("""
        SELECT o FROM Order o
        JOIN FETCH o.items
        WHERE o.status = :status
        ORDER BY o.createdAt DESC
        """)
    List<Order> findByStatus(@Param("status") Status status, Pageable pageable);

    @Query(value = """
        SELECT o.* FROM orders o
        WHERE o.user_id = :userId
        ORDER BY o.created_at DESC
        LIMIT :limit OFFSET :offset
        """, nativeQuery = true)
    List<Order> findByUserIdPaged(@Param("userId") Long userId,
                                  @Param("limit") int limit,
                                  @Param("offset") int offset);

    // Batch insert for bulk operations
    @Modifying
    @Query("""
        INSERT INTO order_items (order_id, sku, quantity, price)
        VALUES (:orderId, :#{#item.sku}, :#{#item.quantity}, :#{#item.price})
        """)
    void batchInsertItems(@Param("orderId") Long orderId,
                          @Param("item") List<OrderItem> items);
}
```

```java
@Service
public class OrderQueryService {

    public OrderListDto listUserOrders(Long userId, int page, int size) {
        // MAX page size enforced — C1 principle
        size = Math.min(size, 100);

        // Count query separate from data query
        var total = orderRepo.countByUserId(userId);
        var orders = orderRepo.findByUserIdPaged(userId, size, page * size);

        return new OrderListDto(orders, total, page, size);
    }
}
```

**EXPLAIN ANALYZE Interpretation:**
```
Before optimization:
  Seq Scan on orders (cost=0.00..52341.00 rows=48723 width=245)
    (actual time=0.123..2341.567 rows=48723 loops=1)  -- 2.3 SECONDS

After adding idx_orders_user_status:
  Index Scan using idx_orders_user_status on orders (cost=0.42..8.44 rows=20 width=245)
    (actual time=0.012..0.034 rows=20 loops=1)  -- 0.034 SECONDS — 67x faster
```

**Expert Note**: Always `EXPLAIN ANALYZE` queries expected to exceed 1000 rows or 100ms. Look for `Seq Scan` on large tables (> 10K rows) — it's always a red flag. For reporting queries, consider materialized views refreshed on a schedule.

---

## DP-5: Schema Version Management

**Use when**: Managing database schema changes in a team, deploying to production, or needing rollback capability.

### ❌ Wrong — Manual SQL, No Version Control

```sql
-- DBA runs this manually on production
ALTER TABLE orders ADD COLUMN discount_code VARCHAR(20);
-- No record of who ran this. No rollback script. Broken if fails mid-migration.
-- Developer's local DB doesn't have this column → "works on my machine"
```

### Root Cause

Manual schema changes create divergence between environments. Without versioned migrations, there is no way to know what state a database is in, no way to roll back, and no way to reproduce the production schema in development.

### ✅ Expert Fix — Flyway

```sql
-- V1__create_orders.sql
CREATE TABLE orders (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    total_amount NUMERIC(12,2) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_orders_user_id ON orders(user_id);
CREATE INDEX idx_orders_status ON orders(status);
```

```sql
-- V2__add_discount_code.sql
ALTER TABLE orders ADD COLUMN discount_code VARCHAR(20);

-- Rollback: V2__undo.sql (for emergency only)
-- ALTER TABLE orders DROP COLUMN discount_code;
```

```sql
-- V3__add_order_attributes.sql
ALTER TABLE orders ADD COLUMN attributes JSONB DEFAULT '{}';
CREATE INDEX idx_orders_attrs ON orders USING GIN (attributes jsonb_path_ops);
```

```java
// Flyway callback for repeatable seed data
@Component
public class FlywaySeedCallback implements Callback {
    @Override
    public boolean supports(Event event, Context context) {
        return event == Event.AFTER_MIGRATE;
    }

    @Override
    public void handle(Event event, Context context) {
        // Seed reference data after migrations complete
    }
}
```

```yaml
spring:
  flyway:
    enabled: true
    locations: classpath:db/migration
    baseline-on-migrate: true      # for existing databases
    validate-on-migrate: true      # checksum verification
    clean-disabled: true           # NEVER auto-clean in production
```

**Naming Convention:**
```
V<version>__<description>.sql
  V1__create_orders.sql
  V1_1__add_index.sql           (minor version)
  V2__add_discount_code.sql
  R__<description>.sql          (repeatable migration)
  U<version>__<description>.sql (undo — Flyway Teams only)
```

**Online DDL Strategies for Large Tables:**
- PostgreSQL: Use `CREATE INDEX CONCURRENTLY` — non-blocking
- MySQL 8.0+: `ALTER TABLE ... ALGORITHM=INPLACE, LOCK=NONE`
- Strategy: Add column DEFAULT NULL → backfill in batches → add NOT NULL constraint with valid default

**Expert Note**: Never modify an applied migration — Flyway's checksum will fail. Always add a new migration. For destructive changes (DROP COLUMN), use expand-contract: add new column → migrate data → deploy code using new column → remove old column in next release.

---

## Quick Database Design Checklist

- [ ] Every query on tables > 10K rows has an index supporting the WHERE clause?
- [ ] Composite index column order aligns with query selectivity?
- [ ] Read replicas configured for read-heavy (> 80% reads) workloads?
- [ ] `@Transactional(readOnly = true)` on all query-only service methods?
- [ ] HikariCP `leak-detection-threshold` enabled (non-prod)?
- [ ] Connection pool size uses formula, not default?
- [ ] All queries returning lists have `LIMIT` or use `Pageable`?
- [ ] N+1 detection: no repository calls inside loops or stream maps?
- [ ] Flyway migrations are versioned, commit-tagged, and never modified retroactively?
- [ ] Destructive changes use expand-contract, not single-step migration?
