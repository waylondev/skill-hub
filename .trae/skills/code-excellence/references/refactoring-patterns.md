# Refactoring Patterns — Architect-Level Reference

## Purpose

Safe, incremental migration patterns for evolving legacy systems without downtime, data loss, or Big Bang risk. Every architect must master these before touching a production system.

---

## RF-1: Strangler Fig Pattern

**Use when**: Replacing a monolith or legacy service incrementally. Cannot afford Big Bang rewrite. Need zero-downtime migration.

### ❌ Wrong — Big Bang Rewrite

```java
// "We'll rebuild everything in 6 months and switch over one weekend"
// Result: 18 months later, still not done, legacy still running,
// both teams diverged, switchover weekend is a disaster.

@RestController
public class OrderController {
    // directly calls legacy monolith — no abstraction
    private final LegacyMonolithClient legacy = new LegacyMonolithClient();

    @PostMapping("/orders")
    public OrderRs create(@RequestBody OrderRq req) {
        return legacy.createOrder(req); // hard dependency on legacy
    }
}
```

### Root Cause

Direct dependency on legacy prevents incremental extraction. Every new feature adds to legacy because there's no routing layer. The system calcifies.

### ✅ Expert Fix — Strangler Fig with Routing Proxy

```java
// Step 1: Introduce routing layer
@Component
public class OrderRoutingService {
    private final LegacyOrderService legacyService;
    private final NewOrderService newService;
    private final MigrationConfig migrationConfig;

    public OrderRs create(OrderRq req) {
        if (migrationConfig.shouldRouteToNew(req)) {
            return newService.create(req);
        }
        return legacyService.create(req);
    }
}

// Step 2: Gradual traffic shift via config
@Component
@ConfigurationProperties("migration.orders")
public class MigrationConfig {
    private int newServicePercentage = 0;     // 0% → 1% → 10% → 50% → 100%
    private Set<String> migratedUserIds;       // specific users for canary
    private boolean allUsersToNew = false;

    public boolean shouldRouteToNew(OrderRq req) {
        if (allUsersToNew) return true;
        if (migratedUserIds.contains(req.userId())) return true;
        return ThreadLocalRandom.current().nextInt(100) < newServicePercentage;
    }
}

// Step 3: Monitor parity — compare results, alert on divergence
@EventListener
public class MigrationAuditor {
    @EventListener
    public void onOrderCreated(OrderCreatedEvent event) {
        if (event.source() == Source.NEW_SERVICE) {
            var legacyResult = legacyService.getOrder(event.orderId());
            var newResult = newService.getOrder(event.orderId());
            var diff = comparator.compare(legacyResult, newResult);
            if (diff.hasSignificantDifference()) {
                alerting.send(new MigrationDivergenceAlert(diff));
            }
        }
    }
}
```

**Migration Timeline:**
```
Week 1-2:  0% traffic, new service in shadow mode, compare results
Week 3:    1% canary users
Week 4:    10% random traffic
Week 5:    50% traffic
Week 6:    100% traffic, legacy still available as fallback
Week 7-8:  100% traffic, legacy in read-only mode
Week 9:    Decommission legacy after verification period
```

**Expert Note**: The Strangler Fig is named after figs that grow around a host tree, eventually replacing it. The key is the routing layer — never let callers know which implementation they're hitting. This gives you the power to roll back instantly (set percentage to 0) if anything goes wrong.

---

## RF-2: Branch by Abstraction

**Use when**: Replacing an internal component (library, algorithm, data structure) without affecting callers. Callers should not know or care about the change.

### ❌ Wrong — Direct Replacement

```java
// Changing the pricing engine — every caller breaks
public class CheckoutService {
    // OLD: directly instantiated
    private final OldPricingEngine pricingEngine = new OldPricingEngine();

    public Money calculateTotal(Cart cart) {
        return pricingEngine.calculate(cart); // callers must change when engine changes
    }
}

// "Just replace OldPricingEngine with NewPricingEngine everywhere"
// Result: 47 files changed, merge conflicts, missed one, production bug
```

### ✅ Expert Fix — Branch by Abstraction

```java
// Step 1: Extract interface (if not exists)
public interface PricingEngine {
    PricingResult calculate(Cart cart);
}

// Step 2: Old implementation implements interface
@Component
@Qualifier("legacy")
public class OldPricingEngine implements PricingEngine {
    @Override
    public PricingResult calculate(Cart cart) { /* existing logic */ }
}

// Step 3: New implementation behind same interface
@Component
@Qualifier("new")
public class NewPricingEngine implements PricingEngine {
    @Override
    public PricingResult calculate(Cart cart) { /* new logic */ }
}

// Step 4: Toggle between implementations
@Component
public class PricingEngineRouter implements PricingEngine {
    private final PricingEngine legacy;
    private final PricingEngine newEngine;
    private final FeatureToggle toggle;

    @Override
    public PricingResult calculate(Cart cart) {
        if (toggle.isEnabled("new-pricing-engine")) {
            return newEngine.calculate(cart);
        }
        return legacy.calculate(cart);
    }
}

// Callers NEVER change — they depend on PricingEngine interface
@Service
public class CheckoutService {
    private final PricingEngine pricingEngine; // interface, unchanged

    public Money calculateTotal(Cart cart) {
        return pricingEngine.calculate(cart).total(); // zero changes needed
    }
}
```

**Expert Note**: Branch by Abstraction is the safest refactoring pattern. The interface acts as a seam — you can swap implementations without touching callers. Combined with feature toggles, you can A/B test the new implementation against the old on production traffic. When confident, delete the old implementation and the router — collapse back to a single implementation.

---

## RF-3: Feature Toggle (Feature Flag)

**Use when**: Decoupling deployment from release. Need to ship code dark, enable per user/percentage, A/B test, or have a kill switch.

### ❌ Wrong — Deploy = Release

```java
// New feature deployed → immediately visible to all users
// No way to disable without rollback. Rollback = redeploy = 15 minutes of downtime.

@PostMapping("/checkout")
public CheckoutRs checkout(@RequestBody CheckoutRq req) {
    // New BNPL payment — deployed Friday 5pm, breaks for 30% of users
    // Cannot disable without reverting and redeploying
    if (req.paymentType() == PaymentType.BNPL) {
        return bnplService.process(req); // no kill switch
    }
    return standardCheckout(req);
}
```

### ✅ Expert Fix — Multi-Dimensional Feature Toggle

```java
// Toggle configuration
@ConfigurationProperties("features")
public class FeatureToggleConfig {
    private Map<String, ToggleRule> toggles;

    public boolean isEnabled(String feature, UserContext user) {
        var rule = toggles.get(feature);
        if (rule == null) return false; // SAFE DEFAULT: disabled if unknown

        return switch (rule.type()) {
            case GLOBAL -> rule.enabled();
            case PERCENTAGE -> user.id().hashCode() % 100 < rule.percentage();
            case USER_LIST -> rule.allowedUsers().contains(user.id());
            case USER_GROUP -> user.hasGroup(rule.allowedGroup());
            case KILL_SWITCH -> false; // emergency: always off
        };
    }
}

// Usage in service — toggle safe by default
@Service
public class CheckoutService {
    private final StandardCheckoutService standard;
    private final BnplCheckoutService bnpl;
    private final FeatureToggleConfig toggles;

    public CheckoutRs checkout(CheckoutRq req, UserContext user) {
        if (req.paymentType() == PaymentType.BNPL
                && toggles.isEnabled("bnpl-checkout", user)) {
            return bnpl.process(req);
        }
        return standard.process(req); // fallback to known-safe path
    }
}
```

```yaml
features:
  toggles:
    bnpl-checkout:
      type: PERCENTAGE         # GLOBAL | PERCENTAGE | USER_LIST | KILL_SWITCH
      enabled: true
      percentage: 5            # 5% canary, then 50%, then 100%
      allowed-users: []        # specific beta testers
      owner: "payments-team"
      expires: "2026-08-01"    # toggle MUST be cleaned up after release
```

**Toggle Lifecycle:**
```
[Created] → [5% Canary] → [50% Ramp] → [100% All Users] → [Code Cleanup] → [Toggle Removed]
```
If ANY issue occurs → KILL_SWITCH → traffic returns to standard path instantly.

**Expert Note**: Feature toggles are technical debt. Every toggle must have an owner and an expiry date. Schedule toggle cleanup as part of your definition-of-done. Toggles left in code for > 2 sprints become landmines — "what happens if I flip this?" that nobody can answer. Kill switch toggles (emergency only) are the exception.

---

## RF-4: Parallel Change (Expand-Contract)

**Use when**: Database schema changes must happen with zero downtime. No "maintenance window". No locking migrations.

### ❌ Wrong — Destructive Single-Step Migration

```sql
-- Flyway V5 — "just rename the column"
ALTER TABLE orders RENAME COLUMN total TO total_amount;
-- Application code still queries "total" → CRASH
-- No rollback — rename is instant and destructive
```

```java
// Code deployed simultaneously — "atomic" deploy
// Reality: DB migration runs before new code deploys → 3-minute crash window
public record OrderDto(BigDecimal totalAmount) {} // expects new column name
```

### ✅ Expert Fix — Expand-Contract

```sql
-- V5_EXPAND: Add new column (safe, no existing code uses it)
ALTER TABLE orders ADD COLUMN total_amount NUMERIC(12,2);
-- Application writes to BOTH columns during transition period
```

```java
// Phase 1: DUAL WRITE — write to both old and new columns
@Repository
public class OrderRepository {
    public void save(Order order) {
        jdbc.update("""
            INSERT INTO orders (user_id, total, total_amount, status)
            VALUES (?, ?, ?, ?)
            """, order.userId(), order.total(), order.total(), order.status());
        // writes identical value to both 'total' and 'total_amount'
    }

    // Phase 1: still read from old column while data syncs
    public Order findById(Long id) {
        return jdbc.queryForObject(
            "SELECT total, ... FROM orders WHERE id = ?", Order.class, id);
    }
}
```

```java
// Phase 2: BACKFILL — migrate existing rows (batch process, not migration)
@Scheduled(fixedDelay = 60000)
public void backfillNullTotals() {
    jdbc.update("""
        UPDATE orders SET total_amount = total
        WHERE total_amount IS NULL
        LIMIT 10000
        """);
    // runs in background, non-blocking, idempotent
}
```

```java
// Phase 3: SWITCH READ — application reads from new column
public Order findById(Long id) {
    return jdbc.queryForObject(
        "SELECT total_amount AS total, ... FROM orders WHERE id = ?", Order.class, id);
    // aliased back to 'total' — application code unchanged!
}
```

```sql
-- Phase 4: CONTRACT — remove old column (days/weeks later, after verification)
-- V6_CONTRACT: DROP old column only after ALL instances use new column
ALTER TABLE orders DROP COLUMN total;
```

**Expert Note**: Expand-Contract follows the same rhythm as breathing: expand (add new), breathe (dual-write + backfill), contract (remove old). The key insight is that **no single step can cause a failure**. Every step is either additive (safe) or only executed after verification that nothing depends on what's being removed. This pattern works for columns, tables, APIs, config keys, and even entire services.

---

## RF-5: Dark Launching / Traffic Mirroring

**Use when**: Validating a new service implementation against real production traffic without affecting users. The new service must prove correctness before serving real users.

### ❌ Wrong — Test in Staging Only, Then Full Switch

```
"Staging tests passed. Let's switch 100% traffic to the new payment service."
Result: Staging has 100 test accounts, 10 test cards. Production has edge cases:
- expired cards with retry, 3DS redirect flows, partial refunds, chargebacks.
New service fails on 3% of real transactions. Money lost. Trust lost.
```

### ✅ Expert Fix — Shadow Traffic with Async Validation

```java
@Component
public class PaymentShadowRouter {
    private final PaymentService production;    // serves real users
    private final PaymentService shadow;        // receives mirrored traffic
    private final ThreadPoolExecutor shadowExecutor =
        new ThreadPoolExecutor(2, 8, 60L, SECONDS, new LinkedBlockingQueue<>(1000),
            new ThreadPoolExecutor.DiscardOldestPolicy()); // NEVER block production

    public PaymentResult process(PaymentRequest req) {
        // 1. Production path — ALWAYS executes (user sees this)
        var result = production.process(req);

        // 2. Shadow path — fire and forget, never block, never throw
        shadowExecutor.submit(() -> {
            try {
                var shadowResult = shadow.process(req);
                compareAndAlert(result, shadowResult, req);
            } catch (Exception e) {
                metrics.shadowError.increment();
                log.warn("Shadow processing failed for payment {}", req.id(), e);
                // NEVER rethrow — shadow failures must not affect production
            }
        });

        return result; // user gets production result, always
    }

    private void compareAndAlert(PaymentResult prod, PaymentResult shadow, PaymentRequest req) {
        if (!prod.equals(shadow)) {
            metrics.shadowDivergence.increment();

            // Alert only if divergence rate > 1%
            if (metrics.shadowDivergence.rate() > 0.01) {
                alerting.send(new ShadowDivergenceAlert(prod, shadow, req));
            }

            // Log full diff for debugging
            log.warn("Shadow divergence for payment {}: prod={}, shadow={}",
                req.id(), prod, shadow);
        } else {
            metrics.shadowMatch.increment();
        }
    }
}
```

```yaml
# Shadow traffic configuration
shadow:
  payment-service:
    enabled: true
    traffic-percentage: 100        # mirror 100% of traffic
    executor:
      core-pool-size: 2
      max-pool-size: 8
      queue-capacity: 1000
    alerts:
      divergence-threshold: 0.01   # alert if > 1% divergence
```

**Shadow Readiness Checklist:**
```
Phase 1:  Shadow 100% traffic → compare results → fix divergences
Phase 2:  Divergence < 1% for 7 consecutive days → ready for canary
Phase 3:  Strangler Fig (RF-1): 1% → 10% → 50% → 100% real traffic
Phase 4:  Shadow still runs for 1 week at 100%, reversed (shadow=old, prod=new)
Phase 5:  Decommission shadow after verification
```

**Expert Note**: Dark launching is the ultimate safety net. You validate against real-world edge cases — the ones staging can never reproduce — with zero user impact. The shadow executor must have a bounded queue with DiscardOldestPolicy: under overload, drop shadow traffic first. Never let validation compromise production.

---

## Quick Refactoring Decision Matrix

| Situation | Pattern | Risk Level |
|-----------|---------|------------|
| Replace monolith incrementally | Strangler Fig (RF-1) | Low |
| Swap internal component/library | Branch by Abstraction (RF-2) | Very Low |
| Decouple deploy from release | Feature Toggle (RF-3) | Very Low |
| DB schema change, zero downtime | Parallel Change (RF-4) | Low |
| Validate new service on real traffic | Dark Launching (RF-5) | Very Low |
| "Just rewrite it" | ❌ Big Bang | **CRITICAL** |
