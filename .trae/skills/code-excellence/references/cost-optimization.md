# Cost Optimization Patterns — Architect-Level Reference

## Purpose

FinOps patterns for controlling cloud infrastructure costs without sacrificing reliability or performance. Every architect must design for cost efficiency as a first-class architectural concern, not an afterthought.

---

## CO-1: Right-Sizing Resources

**Use when**: Cloud bills are growing faster than traffic, or resource utilization is consistently below 30%.

### ❌ Wrong — Over-Provisioned by Default

```yaml
# "Just give it 4 CPUs and 8GB — we'll tune later"
# Later never comes. 90% of services use < 20% of allocated resources.

resources:
  requests:
    cpu: "4000m"      # 4 full cores — service peaks at 800m (20% utilization)
    memory: "8Gi"     # 8GB — service peaks at 2GB (25% utilization)
  limits:
    cpu: "8000m"      # 8 cores — never reached
    memory: "16Gi"    # 16GB — never reached
```

**Cost Impact**: 75% of allocated (and paid-for) capacity is unused. For 50 services, this is thousands of dollars per month in waste.

### ✅ Expert Fix — Data-Driven Sizing with VPA

```yaml
# Step 1: Deploy VPA in recommendation mode (does NOT auto-apply)
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: order-service-vpa
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: order-service
  updatePolicy:
    updateMode: "Off"  # recommendation only — human reviews before applying

# VPA output after 1 week of production data:
# Recommendation:
#   cpu request: 500m  → was 4000m (8x over-provisioned)
#   memory request: 1Gi → was 8Gi (8x over-provisioned)
#   cpu limit: 2000m
#   memory limit: 4Gi
```

```yaml
# Step 2: Apply data-driven sizing — P50 for requests, P95 for limits
resources:
  requests:
    cpu: "500m"       # P50 usage from 7-day metrics
    memory: "1Gi"     # P50 usage
  limits:
    cpu: "2000m"      # P95 usage + 20% buffer
    memory: "4Gi"     # P95 usage + 50% buffer (memory is less elastic than CPU)
```

```java
// Resource tuning formula
public class ResourceSizing {

    /**
     * @param p50Usage  Median usage over 7+ days
     * @param p95Usage  95th percentile usage
     * @param p99Usage  99th percentile for safety check
     */
    public record ResourceRecommendation(
        String cpuRequest,
        String memRequest,
        String cpuLimit,
        String memLimit,
        double projectedSavingsPercent
    ) {}

    public ResourceRecommendation tune(String serviceName,
            double cpuP50, double cpuP95, double cpuP99,
            double memP50, double memP95, double memP99) {

        // CPU: request = P50, limit = P95 × 1.2
        // Memory: request = P50, limit = P95 × 1.5 (memory is stickier)

        double cpuRequest = cpuP50;
        double cpuLimit = cpuP95 * 1.2;
        double memRequest = memP50;
        double memLimit = memP95 * 1.5;

        // Safety check: ensure P99 spike doesn't immediately OOM
        if (memP99 > memLimit * 0.9) {
            memLimit = memP99 * 1.2; // bump limit to handle P99
        }

        double savingsPercent = (1 - (cpuRequest / 4000)) * 100; // baseline: 4000m

        return new ResourceRecommendation(
            formatCpu(cpuRequest), formatMem(memRequest),
            formatCpu(cpuLimit), formatMem(memLimit),
            savingsPercent
        );
    }
}
```

**Expert Note**: VPA recommendations are free architectural advice. Deploy VPA in `Off` mode for all services for 1-2 weeks before production launch. The data will tell you exactly how much to allocate. Re-run quarterly — usage patterns change as features are added. The rule: requests = what you use normally (P50), limits = what you might use under load (P95 for CPU, P99 for memory).

---

## CO-2: Spot / Preemptible Instance Strategy

**Use when**: Running stateless, fault-tolerant workloads (web servers, API gateways, batch processors, CI/CD runners). Spot instances are 60-90% cheaper than on-demand.

### ❌ Wrong — All On-Demand, No Spot

```yaml
# Every node is on-demand → paying full price for all capacity
# No graceful shutdown handling → spot would cause request failures

apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      containers:
        - name: api
          lifecycle: {}   # NO preStop hook — SIGTERM kills mid-request
      nodeSelector: {}    # any node, no preference
---
# Monthly compute cost: $12,000 (100% on-demand)
```

### ✅ Expert Fix — Hybrid Spot + On-Demand + Graceful Shutdown

```yaml
# Strategy: 70% spot + 30% on-demand baseline
# Spot handling: graceful shutdown + PodDisruptionBudget

# Step 1: Graceful shutdown — complete in-flight requests
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      terminationGracePeriodSeconds: 30   # 30s to drain
      containers:
        - name: api
          lifecycle:
            preStop:
              exec:
                command:
                  - /bin/sh
                  - -c
                  - |
                    echo "Spot termination detected — draining..."
                    # Signal health endpoint to return NOT_READY (removed from LB)
                    curl -X POST http://localhost:8080/actuator/drain
                    # Wait for in-flight requests to complete (max 25s)
                    sleep 25
                    echo "Drain complete — shutting down"

      # Spread across spot and on-demand
      affinity:
        nodeAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              preference:
                matchExpressions:
                  - key: node-type
                    operator: In
                    values: ["spot"]       # prefer spot (cheaper)
            - weight: 50
              preference:
                matchExpressions:
                  - key: node-type
                    operator: In
                    values: ["on-demand"]   # fallback to on-demand

      # Tolerate spot taint
      tolerations:
        - key: "spot-instance"
          operator: "Equal"
          value: "true"
          effect: "NoSchedule"

---
# Step 2: PodDisruptionBudget — never let ALL pods die at once
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: api-pdb
spec:
  minAvailable: 2    # at least 2 pods MUST always be running
  selector:
    matchLabels:
      app: api
```

```java
// Graceful drain controller
@RestController
public class DrainController {
    private final AtomicBoolean draining = new AtomicBoolean(false);

    @PostMapping("/actuator/drain")
    public void startDrain() {
        draining.set(true);
        log.info("Drain mode activated — no new requests accepted");
    }

    // Health endpoint: returns DOWN when draining (removed from load balancer)
    @GetMapping("/actuator/health")
    public Health health() {
        if (draining.get()) {
            return Health.down().withDetail("reason", "spot-termination-draining").build();
        }
        return Health.up().build();
    }
}
```

**Cost Comparison:**
| Configuration | Monthly Compute | Savings |
|---------------|-----------------|---------|
| 100% On-Demand | $12,000 | — |
| 70% Spot + 30% On-Demand | $3,600 + $3,600 = $7,200 | **40%** |
| With graceful shutdown + PDB | $7,500 (small on-demand buffer) | **37.5%** |

**Expert Note**: Spot instances get a 2-minute termination warning. Your service needs to drain and exit gracefully within that window. The `preStop` hook + PodDisruptionBudget combination is essential — PDB ensures you never lose all pods simultaneously. Never run databases or stateful workloads on spot. Stateless = spot-safe.

---

## CO-3: Data Transfer Cost Optimization

**Use when**: Cloud bills show significant data transfer charges (often the #1 hidden cost).

### ❌ Wrong — Cross-AZ/Cross-Region Without Awareness

```yaml
# Service in us-east-1a calling Redis in us-east-1c — every request = cross-AZ cost
# $0.01/GB each direction. 1TB/month = $20. Seems small. Reality:

# Real cost: 50 microservices × avg 500KB transferred × 100 RPS × 86400s/day
# = 500KB × 100 × 86400 × 50 = 216TB/day cross-AZ
# Cost: 216TB × $0.02/GB × 30 days = $129,600/month in cross-AZ fees alone
```

### ✅ Expert Fix — AZ-Affinity + Compression + CDN

```yaml
# Strategy 1: Topology-aware routing — same-AZ preferred
apiVersion: v1
kind: Service
metadata:
  name: order-service
spec:
  topologyKeys:
    - "topology.kubernetes.io/zone"     # prefer same AZ
    - "kubernetes.io/hostname"          # fallback to cross-AZ

---
# Strategy 2: Compress large responses
```

```java
// GZIP compression for API responses > 1KB
@Configuration
public class CompressionConfig implements WebMvcConfigurer {
    @Bean
    public FilterRegistrationBean<CompressingFilter> compressionFilter() {
        var filter = new FilterRegistrationBean<>(new CompressingFilter());
        filter.addUrlPatterns("/api/*");
        filter.addInitParameter("compressionThreshold", "1024"); // only compress > 1KB
        filter.addInitParameter("includeContentTypes",
            "application/json,application/xml,text/plain,text/html");
        return filter;
    }
}

// Typical compression ratio for JSON API: 70-85% reduction
// 500KB payload → 75-150KB → 3-7× less transfer cost
```

```yaml
# Strategy 3: CDN for static assets + cacheable API responses
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    nginx.ingress.kubernetes.io/configuration-snippet: |
      # Cache static content at CDN edge — zero origin transfer
      add_header Cache-Control "public, max-age=86400";
      add_header X-CDN-Cache "HIT";
```

**Data Transfer Cost Hierarchy (AWS example):**
| Transfer Type | Cost per GB | Optimize |
|---------------|-------------|----------|
| Same AZ | FREE | Keep traffic here |
| Cross-AZ (same region) | $0.01/GB | Minimize via topology-aware routing |
| Cross-Region | $0.02/GB | Replicate data, don't transfer live |
| Internet egress | $0.09/GB | CDN ($0.02-0.06/GB) + compression |
| CloudFront (CDN) | $0.02-0.06/GB | Cheaper than direct internet egress |

**Expert Note**: Data transfer costs are invisible in development and catastrophic in production. AZ-affinity routing (topologySpreadConstraints) is free to implement and can eliminate cross-AZ costs entirely for most inter-service calls. Compression is also free — a one-line config change can reduce API response sizes by 70-85%. These two optimizations alone can reduce transfer costs by 90%+.

---

## CO-4: Storage Tiering Strategy

**Use when**: Data accumulates over time but access frequency drops dramatically. Keeping all data on high-performance storage is wasteful.

### ❌ Wrong — Single-Tier, Keep Everything Forever

```yaml
# All data on SSD (gp3/io2) — expensive. 90% of data accessed < once per month.
# No lifecycle policies. 10TB of 6-month-old logs on premium storage.
# Log retention: indefinite. "Storage is cheap" → accumulated $8,000/month.

retention_policy: keep_forever
storage_class: PREMIUM_SSD
```

**Cost**: 10TB × $0.08/GB-month (gp3) = $800/month. With 90% cold data, $720/month is waste.

### ✅ Expert Fix — Tiered Lifecycle with Automated Transitions

```yaml
# Hot/Warm/Cold tier policy
storage_lifecycle:
  # HOT (SSD): 0-30 days — active queries, fast access needed
  hot_tier:
    storage: SSD_GP3
    retention: 30d
    cost_per_gb: $0.08

  # WARM (HDD): 31-90 days — infrequent access, slower is acceptable
  warm_tier:
    storage: HDD_SC1
    retention: 90d
    cost_per_gb: $0.03   # 62% cheaper
    transition_after: 30d

  # COLD (Archive): 91-365 days — compliance/audit only
  cold_tier:
    storage: ARCHIVE_GLACIER
    retention: 365d
    cost_per_gb: $0.01   # 87% cheaper
    transition_after: 90d
    restore_time: "3-5 hours"

  # PURGE: > 365 days — deleted unless legal hold
  purge_after: 365d
```

```sql
-- Database log partitioning by month
CREATE TABLE application_logs (
    id BIGSERIAL,
    level VARCHAR(10),
    message TEXT,
    created_at TIMESTAMPTZ NOT NULL
) PARTITION BY RANGE (created_at);

CREATE TABLE application_logs_2026_05
    PARTITION OF application_logs
    FOR VALUES FROM ('2026-05-01') TO ('2026-06-01');

-- Cold partitions moved to cheaper tablespace
CREATE TABLESPACE cold_storage LOCATION '/data/cold';

ALTER TABLE application_logs_2025_12 SET TABLESPACE cold_storage;
-- Archived month of logs now on HDD — queries still work, just slower

-- Purge old partitions (cron/scheduled job)
DROP TABLE application_logs_2024_06;  -- > 365 days old
```

```java
// Log retention policy in application code
@Component
public class LogRetentionManager {

    @Scheduled(cron = "0 0 2 1 * *")  // 2 AM, 1st of each month
    public void enforceRetention() {
        var cutoff = LocalDate.now().minusMonths(12);
        int deleted = logRepo.deleteByCreatedAtBefore(cutoff.atStartOfDay());
        log.info("Log retention: deleted {} records older than {}", deleted, cutoff);
    }
}
```

**Expert Note**: The 80/20 rule applies to data: 80% of storage cost comes from data that's accessed less than 20% of the time. Tiered storage is not optional at scale — it's the difference between a $1,000/month storage bill and a $10,000/month one. Set retention policies BEFORE you have data — retrofitting is painful. The purge policy is as important as the keep policy.

---

## CO-5: Observability Cost Control

**Use when**: Observability costs (logs, metrics, traces) exceed 10-15% of infrastructure spend. Observability is essential but should not dominate the budget.

### ❌ Wrong — Log Everything, Sample Nothing

```yaml
# Every log line shipped. Every trace recorded. Every metric at 1s resolution.
# 50 services × 1000 req/s × 1KB log per request = 50 MB/s of logs
# 50 MB/s × 86400s × 30 days = 129TB/month of logs
# Cost at $0.50/GB ingested: $64,500/month — JUST FOR LOGS

logging:
  level:
    root: INFO             # even framework internals logged
    com.example: DEBUG     # full request/response payloads in production

tracing:
  sampling: 1.0            # 100% — every trace captured

metrics:
  scrape_interval: 1s      # ultra-fine resolution
```

### ✅ Expert Fix — Tiered Sampling + Filtering

```yaml
# Logging — keep what matters
logging:
  level:
    root: WARN                                                     # framework noise → OFF
    com.example.orders.api: INFO                                   # API entry points
    com.example.orders.service: ${LOG_LEVEL:WARN}                  # configurable per env
    com.example.payment: ERROR                                     # sensitive: errors only
    org.springframework: WARN                                      # framework → WARN
    com.zaxxer.hikari: ERROR                                       # pool chatter → OFF

  # Structured logging — machine-parseable, lower storage cost
  pattern: >
    {"timestamp":"%d{ISO8601}","level":"%p","service":"${SERVICE_NAME}",
     "traceId":"%X{traceId}","spanId":"%X{spanId}",
     "class":"%c{1.}","message":"%m%n%throwable"}

---
# Tracing — head-based sampling
tracing:
  sampling:
    strategy: PROBABILISTIC
    probability: 0.01         # 1% normal traffic
    error_always_sample: true # 100% of errors (regardless of sampling rate)
    latency_threshold: 500ms  # 100% of slow requests (>500ms)

    # Special rules:
    routes:
      - path: "/api/payment/**"
        sampling: 1.0         # 100% for payment — RECONCILE EVERYTHING
      - path: "/health"
        sampling: 0.0         # health checks = zero trace

---
# Metrics — appropriate resolution
metrics:
  default_interval: 60s       # most metrics: 1 minute
  critical_intervals:
    http_request_duration: 15s  # latency SLA monitoring
    error_rate: 30s            # error detection
    circuit_breaker_state: 15s # resilience monitoring
```

```java
// OpenTelemetry sampling configuration
@Configuration
public class TracingConfig {

    @Bean
    public Sampler sampler() {
        return Sampler.parentBased(
            // Parent-based: if parent sampled → child sampled (trace completeness)
            new Sampler() {
                private final RateLimitingSampler rateLimiter =
                    new RateLimitingSampler(100); // max 100 traces/sec

                @Override
                public SamplingResult shouldSample(
                        Context parentContext, String traceId, String name,
                        SpanKind spanKind, Attributes attributes,
                        List<LinkData> parentLinks) {

                    // RULE 1: Any request with error → ALWAYS sample
                    if (hasError(attributes)) {
                        return SamplingResult.recordAndSample();
                    }

                    // RULE 2: Payment endpoints → ALWAYS sample
                    if (name.contains("PaymentService") || name.contains("/api/payment")) {
                        return SamplingResult.recordAndSample();
                    }

                    // RULE 3: Slow requests (> 500ms) → ALWAYS sample
                    Long latency = attributes.get(SemanticAttributes.HTTP_RESPONSE_LENGTH);
                    // (simplified — actual latency from span duration, checked post-completion)

                    // RULE 4: Normal traffic → probabilistic 1%
                    return Math.random() < 0.01
                        ? SamplingResult.recordAndSample()
                        : SamplingResult.drop();
                }

                private boolean hasError(Attributes attrs) {
                    return Boolean.TRUE.equals(
                        attrs.get(SemanticAttributes.ERROR));
                }
            }
        );
    }
}
```

**Cost Control by Signal:**

| Signal | Keep 100% | Keep 1% | Drop |
|--------|-----------|---------|------|
| Logs | ERROR + Payment audit | WARN from non-critical | INFO/DEBUG (prod),  framework noise |
| Traces | Errors, payments, slow (>500ms) | 1% normal traffic | Health checks, static assets |
| Metrics | Error rate, latency P50/P99, CB state | Custom business metrics | Health check counters (use probe, not metric) |

**Expected Savings**: 70-90% reduction in observability costs while keeping 100% of critical signals.

**Expert Note**: The goal is not to reduce observability — it's to eliminate noise. If you have 1M log lines and 100 of them are errors, shipping all 1M lines is 99.99% waste. The ERROR-always-samples rule ensures you never miss a problem. The 1% normal-traffic sampling gives you statistically valid latency histograms without the cost of 100% capture.

---

## Quick Cost Optimization Checklist

- [ ] VPA deployed (Off mode) — resource recommendations reviewed quarterly?
- [ ] CPU/Memory requests = P50 usage, limits = P95 + buffer?
- [ ] Stateless services running on spot instances with graceful shutdown?
- [ ] PodDisruptionBudget preventing simultaneous spot termination?
- [ ] Topology-aware service routing for same-AZ traffic?
- [ ] API responses compressed (gzip/brotli) for payloads > 1KB?
- [ ] Static assets + cacheable APIs served via CDN?
- [ ] Storage lifecycle: Hot (SSD) → Warm (HDD) → Cold (Archive) → Purge?
- [ ] Log retention policy defined and automated (not "keep forever")?
- [ ] Observability: ERROR=100%, WARN=sampled, INFO/DEBUG=off in prod?
- [ ] Trace sampling: 100% errors + payments, 1% normal traffic?
- [ ] Resource tagging for cost allocation (team/project/environment)?
