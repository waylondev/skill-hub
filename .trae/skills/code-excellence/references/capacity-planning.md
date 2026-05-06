# Capacity Planning Patterns — Architect-Level Reference

## Purpose

Systematic approaches to estimating, provisioning, and scaling infrastructure. Prevents both under-provisioning (outages) and over-provisioning (waste). Every architect must quantify capacity decisions, not guess.

---

## CP-1: Load Estimation & Sizing

**Use when**: Launching a new service, forecasting growth, or justifying infrastructure budget. Required before any production deployment.

### ❌ Wrong — Guess-Based Sizing

```yaml
# "Our monolith runs on 4 cores, so microservices need 4 cores each"
# Reality: 20 microservices × 4 cores = 80 cores, 90% idle usage

resources:
  requests:
    cpu: "4000m"      # "seems reasonable"
    memory: "8Gi"     # "8GB should be enough"
  limits:
    cpu: "8000m"
    memory: "16Gi"
```

### Root Cause

Without load estimation, sizing is either wasteful (over-provisioned) or dangerous (under-provisioned). Neither is acceptable in production.

### ✅ Expert Fix — Formula-Based Estimation

```
Step 1: Estimate Peak Load (λ = requests per second)
  - Daily active users (DAU) × avg requests per session / peak hours in seconds
  - Example: 100K DAU × 50 requests / (3 peak hours × 3600s) = 463 RPS

Step 2: Apply Little's Law (L = λ × W)
  - L = concurrent requests in system
  - λ = arrival rate (RPS)
  - W = average latency (seconds)
  - Example: 463 RPS × 0.05s = 23.15 concurrent requests

Step 3: Calculate Instance Count
  - instances = ceil(L / max_concurrent_per_instance)
  - Example: ceil(23.15 / 10) = 3 instances minimum

Step 4: Add Safety Margin
  - Critical services: 2× peak + 1 extra (N+1 redundancy)
  - Non-critical: 1.5× peak
  - Example: 3 × 2 + 1 = 7 instances (critical payment service)
```

```java
// Load estimation utility
public class CapacityCalculator {

    public record Estimate(
        int peakRps,
        int concurrentRequests,
        int minInstances,
        int recommendedInstances,
        SafetyMargin margin
    ) {}

    public enum SafetyMargin {
        CRITICAL(2.0, true),     // payment, auth — 2x + N+1
        HIGH(1.5, false),       // order processing
        NORMAL(1.3, false),     // most services
        LOW(1.1, false);        // internal tools

        final double factor;
        final boolean requireNPlusOne;

        SafetyMargin(double factor, boolean requireNPlusOne) {
            this.factor = factor;
            this.requireNPlusOne = requireNPlusOne;
        }
    }

    public Estimate calculate(int dailyActiveUsers, int requestsPerSession,
                               int peakHours, double avgLatencyMs,
                               int maxConcurrentPerInstance, SafetyMargin margin) {
        int peakRps = (int) Math.ceil(
            (double) (dailyActiveUsers * requestsPerSession) / (peakHours * 3600));
        int concurrent = (int) Math.ceil(peakRps * (avgLatencyMs / 1000.0));
        int minInstances = (int) Math.ceil(
            (double) concurrent / maxConcurrentPerInstance);
        int recommended = (int) Math.ceil(minInstances * margin.factor);
        if (margin.requireNPlusOne) recommended += 1;

        return new Estimate(peakRps, concurrent, minInstances, recommended, margin);
    }
}
```

```yaml
# Resulting K8s config (auto-generated from estimation)
autoscaling:
  minReplicas: 3       # from formula minimum
  maxReplicas: 10      # min × 3 for overflow tolerance
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
```

**Expert Note**: Little's Law is the single most useful formula in capacity planning. It connects the three variables every architect cares about: arrival rate (traffic), latency (performance), and concurrency (capacity). The safety margin is not optional — it covers traffic spikes, instance failures, and deploy-roll events. Critical services NEED N+1 redundancy: you must survive losing one instance during peak.

---

## CP-2: Horizontal vs Vertical Scaling

**Use when**: Choosing between adding more instances (horizontal) or bigger instances (vertical) for a service.

### ❌ Wrong — Scale Everything Horizontally

```
"K8s handles it — just add more pods."

Problems:
- Stateful services (DB) cannot scale horizontally without sharding
- License costs per core — 8 × 2-core instances = 16 licenses vs 1 × 16-core = 1 license
- Inter-pod communication overhead — chatty services get slower with more instances
- Cold start amplification — 10 pods × 30s startup = 5 minutes to reach full capacity
```

### ✅ Expert Fix — Decision Framework

```java
public enum ScalingStrategy {
    HORIZONTAL, VERTICAL, HYBRID
}

public class ScalingDecisionEngine {

    public record ScalingRecommendation(
        ScalingStrategy strategy,
        String reasoning,
        String constraints
    ) {}

    public ScalingRecommendation decide(ServiceProfile profile) {
        if (profile.stateful()) {
            return new ScalingRecommendation(ScalingStrategy.VERTICAL,
                "Stateful services require vertical scaling. " +
                "Distributed state (sharding) adds complexity disproportional to benefit.",
                "Read replicas for read-heavy workloads. Sharding only at > 10TB data.");
        }

        if (profile.licensePerCore() && profile.licenseCost() > 10000) {
            return new ScalingRecommendation(ScalingStrategy.VERTICAL,
                "Per-core licensing makes horizontal scaling cost-prohibitive. " +
                "16 cores × 1 license vs 2 cores × 8 licenses = 8× cost difference.",
                "Use vertical until license cost plateau, then evaluate horizontal.");
        }

        if (profile.warmUpTime().toSeconds() > 30) {
            return new ScalingRecommendation(ScalingStrategy.VERTICAL,
                "Long warm-up time makes horizontal scaling slow to react. " +
                "Vertical scaling provides instant capacity increase.",
                "Optimize warm-up (< 10s target) before horizontal scaling.");
        }

        if (profile.amdahlParallelFraction() < 0.5) {
            return new ScalingRecommendation(ScalingStrategy.VERTICAL,
                "Amdahl's Law: parallel speedup is limited by serial fraction. " +
                "At 50% parallel, max speedup = 2× regardless of instances.",
                "Profile and increase parallel fraction before horizontal scaling.");
        }

        return new ScalingRecommendation(ScalingStrategy.HORIZONTAL,
            "Stateless, fast warm-up, no license constraints — ideal for horizontal scaling.",
            "Set min=max replicas for predictable capacity, or HPA for elastic workloads.");
    }
}
```

**Decision Matrix:**

| Factor | Horizontal | Vertical |
|--------|------------|----------|
| State management | Needs externalization or sharding | Native (local state) |
| License cost (per-core) | High (many cores) | Lower (fewer cores) |
| Warm-up time requirement | < 10s ideal | Tolerant (single instance) |
| Failure blast radius | Small (per-instance) | Large (single instance) |
| Scaling speed | Instant (add pods) | Slow (resize VM, restart) |
| Complexity | Higher (load balancing, sticky sessions) | Lower |

**Amdahl's Law Reminder:**
```
Speedup = 1 / ((1 - P) + (P / N))
  P = parallel fraction (0.0 to 1.0)
  N = number of instances

Example: 80% parallelizable (P=0.8), 10 instances:
  Speedup = 1 / (0.2 + 0.08) = 1 / 0.28 = 3.57×
  → 10 instances only give 3.57× speedup. Diminishing returns.
```

**Expert Note**: The default instinct in the cloud era is "scale horizontally." This is correct for stateless microservices but dead wrong for databases, license-heavy software, and services with significant serial computation. Always profile first — Amdahl's Law reveals whether horizontal scaling will actually help.

---

## CP-3: Auto-Scaling Configuration

**Use when**: Configuring K8s HPA or cloud auto-scaling groups. Auto-scaling without proper tuning is worse than static sizing.

### ❌ Wrong — Default HPAs, Aggressive Scaling

```yaml
# Default HPA — scales on CPU only, no custom metrics
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: order-service
spec:
  minReplicas: 1
  maxReplicas: 5
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          averageUtilization: 50   # too aggressive → scales on every CPU spike
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 0   # scales down instantly → flapping
```

**Problem**: CPU is a lagging indicator — by the time CPU spikes, requests are already queuing. Aggressive scale-down causes flapping (scale up, cool down, scale down, spike, scale up...). The 50% CPU target means scaling at normal load, not overload.

### ✅ Expert Fix — Multi-Metric, Behavior-Tuned HPA

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: order-service
spec:
  minReplicas: 3
  maxReplicas: 10
  metrics:
    # Primary: Request latency — LEADING indicator
    - type: Pods
      pods:
        metric:
          name: http_request_duration_milliseconds_avg
        target:
          type: AverageValue
          averageValue: "200"    # scale when avg latency > 200ms

    # Secondary: CPU — confirm resource pressure
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70

    # Tertiary: Request queue depth — most direct signal
    - type: Object
      object:
        metric:
          name: tomcat_threads_busy
        describedObject:
          apiVersion: v1
          kind: Service
          name: order-service
        target:
          type: AverageValue
          averageValue: "8"     # scale when > 8 busy threads per pod

  behavior:
    scaleUp:
      stabilizationWindowSeconds: 30   # wait 30s before scaling — smooth out spikes
      policies:
        - type: Percent
          value: 100                   # can double instantly if needed (max 2 pods)
          periodSeconds: 60
        - type: Pods
          value: 2                     # or add 2 pods per minute
          periodSeconds: 60
      selectPolicy: Max                # use the more aggressive policy

    scaleDown:
      stabilizationWindowSeconds: 300  # wait 5 MINUTES before scaling down
      policies:
        - type: Percent
          value: 10                    # remove max 10% of pods per minute
          periodSeconds: 60
        - type: Pods
          value: 1                     # or 1 pod per minute (whichever is less)
          periodSeconds: 60
      selectPolicy: Min                # use the LESS aggressive policy
```

**HPA Tuning Principles:**
| Parameter | Recommended | Rationale |
|-----------|-------------|-----------|
| Scale-up stabilization | 30-60s | Prevents scaling on momentary spikes |
| Scale-down stabilization | 300s+ (5 min) | Prevents flapping — services take time to cool |
| Scale-up rate | Fast (100% or 2+ pods/min) | Overload kills users immediately |
| Scale-down rate | Slow (10% or 1 pod/min) | Idle capacity is cheap, downtime is expensive |
| CPU target | 70% (not 50%) | 50% wastes half your capacity |

**Expert Note**: Scale-up is urgent, scale-down is not. The cost of one unnecessary scale-down (followed by a scale-up during a spike) is far higher than keeping an idle pod for 5 extra minutes. Set `minReplicas` to handle steady-state traffic — HPA is for peaks, not baseline.

---

## CP-4: Database Scaling Patterns

**Use when**: Single database instance cannot handle load or data volume. Requires architectural change, not just "bigger instance."

### ❌ Wrong — Keep Scaling Vertically

```
"Just upgrade to the 64-core instance. 256GB RAM."
Cost: $12,000/month. Still single point of failure.
Writes bottlenecked by single-writer architecture.
Read replicas added ad-hoc → no routing strategy → inconsistent reads.
```

### ✅ Expert Fix — Sharding Strategy

```java
// Sharding key selection — the most critical decision
public enum ShardingStrategy {
    TENANT_ID,      // SaaS: each tenant isolated
    USER_ID,        // consumer apps: user's data together
    REGION,         // global app: data close to users
    TIME_RANGE,     // time-series: partition by month/year
    ENTITY_ID       // key entity (order, transaction)
}

public class ShardingRouter {

    // Consistent hashing for user_id sharding
    private final int shardCount;
    private final HashFunction hash = Hashing.murmur3_128();

    public ShardRoute route(Long userId) {
        int shard = Math.abs(hash.hashLong(userId).asInt()) % shardCount;
        return new ShardRoute(shard, datasourceFor(shard));
    }

    // CRITICAL RULE: all queries for a user stay in their shard
    // Cross-shard queries: ONLY for analytics/aggregation, NEVER for OLTP
}

// Service layer — transparent sharding
@Service
public class OrderService {
    private final ShardingRouter router;

    public List<Order> findUserOrders(Long userId) {
        var shard = router.route(userId);
        return shard.repository().findByUserId(userId);
        // Query hits ONE shard — fast, predictable, horizontally scalable
    }

    public Order create(OrderRequest req) {
        var shard = router.route(req.userId());
        return shard.repository().save(Order.from(req));
        // Writes ALWAYS go to user's home shard
    }
}
```

**Sharding Decision Matrix:**

| Strategy | Use Case | Cross-Shard Query Frequency | Complexity |
|----------|----------|---------------------------|------------|
| Tenant ID | SaaS, B2B | Very Low (analytics only) | Low |
| User ID | B2C apps | Low | Medium |
| Region | Global deployment | Low (replication for DR) | Low |
| Time Range | Logs, metrics, time-series | Medium (range queries) | Medium |
| Entity ID | High-volume transactional | Very Low (entity-scoped) | Medium |

**When to Stop Vertical Scaling:**

| Signal | Threshold |
|--------|-----------|
| DB size | > 1TB active data |
| Writes/second | > 5000 writes/s on single master |
| Connection count | > 1000 concurrent connections |
| Cost | Monthly cost exceeds 3× baseline |
| Latency | P99 > 50ms on indexed queries |

**Expert Note**: Sharding is not a scaling option — it's a data modeling decision. The sharding key determines every query pattern for the lifetime of the system. Choose wrong, and you'll have cross-shard queries everywhere. The golden rule: **every OLTP query must hit exactly one shard**. If you cannot guarantee this with your proposed key, do not shard yet.

---

## CP-5: Rate Limiting at Scale

**Use when**: Protecting services from abuse, enforcing tiered access, or preventing noisy-neighbor problems in multi-tenant systems.

### ❌ Wrong — In-Memory Rate Limiter

```java
// ConcurrentHashMap per instance — no global coordination
public class LocalRateLimiter {
    private final Map<String, TokenBucket> buckets = new ConcurrentHashMap<>();

    public boolean allow(String key) {
        return buckets.computeIfAbsent(key, k -> new TokenBucket(100, 60))
            .tryConsume(); // Each instance has its OWN counter!
    }
}
// 10 instances → each allows 100/min → actual limit = 1000/min — 10× WRONG
// Instance restart → all counters reset → limit reset
```

### ✅ Expert Fix — Redis Global + Local Fallback

```java
@Component
public class DistributedRateLimiter {

    // Tiered rate limits
    public enum Tier {
        FREE(10, 60),        // 10 req/min
        PRO(100, 60),        // 100 req/min
        ENTERPRISE(1000, 60); // 1000 req/min

        final int maxRequests;
        final int windowSeconds;

        Tier(int maxRequests, int windowSeconds) {
            this.maxRequests = maxRequests;
            this.windowSeconds = windowSeconds;
        }
    }

    // Redis Lua script — atomic counter
    private static final String RATE_LIMIT_SCRIPT = """
        local key = KEYS[1]
        local limit = tonumber(ARGV[1])
        local window = tonumber(ARGV[2])

        local current = redis.call('INCR', key)
        if current == 1 then
            redis.call('EXPIRE', key, window)
        end

        if current > limit then
            return 0  -- rate limited
        end
        return 1  -- allowed
        """;

    private final RedisScript<Long> script;

    // LOCAL fallback — survive Redis outage
    private final Cache<String, TokenBucket> localFallback = Caffeine.newBuilder()
        .expireAfterWrite(2, TimeUnit.MINUTES)
        .maximumSize(10_000)
        .build();

    public boolean allow(String userId, String endpoint, Tier tier) {
        String key = "ratelimit:" + userId + ":" + endpoint;

        try {
            Long result = redis.execute(script, List.of(key),
                tier.maxRequests, tier.windowSeconds);
            return result == 1L;
        } catch (RedisConnectionException e) {
            // Redis down → fall back to local (slightly inaccurate, but service survives)
            metrics.rateLimitFallback.increment();
            var bucket = localFallback.get(key,
                k -> new TokenBucket(tier.maxRequests, tier.windowSeconds));
            return bucket.tryConsume();
        }
    }

    // LOCAL Token Bucket (Caffeine-cached, instance-local)
    static class TokenBucket {
        private final long maxTokens;
        private final double refillRate;
        private double tokens;
        private long lastRefillTime;

        synchronized boolean tryConsume() {
            refill();
            if (tokens >= 1.0) {
                tokens -= 1.0;
                return true;
            }
            return false;
        }

        private void refill() {
            long now = System.currentTimeMillis();
            double elapsed = (now - lastRefillTime) / 1000.0;
            tokens = Math.min(maxTokens, tokens + elapsed * refillRate);
            lastRefillTime = now;
        }
    }
}
```

```java
// Apply to endpoints
@RestController
public class ApiController {
    private final DistributedRateLimiter limiter;

    @GetMapping("/api/orders")
    public ResponseEntity<?> listOrders(
            @RequestAttribute("userId") String userId,
            @RequestAttribute("tier") DistributedRateLimiter.Tier tier) {

        if (!limiter.allow(userId, "list-orders", tier)) {
            return ResponseEntity.status(429)
                .header("Retry-After", "60")
                .header("X-RateLimit-Limit", String.valueOf(tier.maxRequests))
                .body(new RateLimitExceededError(tier));
        }

        return ResponseEntity.ok(orderService.listForUser(userId));
    }
}
```

**Rate Limiting at Scale Checklist:**
- [ ] Global counter (Redis) with Lua atomicity — no race conditions across instances
- [ ] Local fallback (Caffeine) — service survives Redis outage gracefully
- [ ] Rate limit headers in response (`X-RateLimit-*`) — client knows their quota
- [ ] Tiered limits based on user plan/role — free vs pro
- [ ] Metrics: tracking rate-limited request count per endpoint
- [ ] Rate limit configuration externalized (not in code) — C12 applies

**Expert Note**: A rate limiter that fails closed (blocks everything when Redis is down) is worse than one that fails open (allows everything). The Caffeine fallback provides graceful degradation — slightly inaccurate limits during Redis outage vs complete service denial. Also: always return rate limit info in headers. Clients that hit limits blind will retry, making the problem worse.

---

## Quick Capacity Planning Checklist

- [ ] Peak RPS estimated using Little's Law (not guessing)?
- [ ] Safety margin applied (2× for critical, 1.5× for normal)?
- [ ] N+1 redundancy for critical services?
- [ ] Scaling strategy decision documented (horizontal vs vertical vs hybrid)?
- [ ] Amdahl's Law validated for horizontally-scaled services?
- [ ] HPA uses multi-metric (latency + CPU + queue depth), not just CPU?
- [ ] Scale-down stabilization ≥ 300s to prevent flapping?
- [ ] Database sharding key chosen such that all OLTP queries hit exactly one shard?
- [ ] Rate limiter: Redis global + Caffeine local fallback?
- [ ] Rate limit tier aligned with business model (free/pro/enterprise)?
- [ ] Rate limit response includes `Retry-After` + `X-RateLimit-*` headers?
