# Observability Patterns — Principal Architect Reference

## Purpose

Operationalizing observability as a first-class architectural concern. Beyond "add metrics and logs" (C11) — this covers SLI/SLO/SLA design, dashboard architecture, alerting strategy, and error budget governance. Essential for any service with an uptime commitment.

---

## OB-1: SLI / SLO / SLA Design

**Use when**: Defining service reliability targets. Without explicit SLOs, "reliable" is an opinion. With SLOs, it's a measurable contract.

### Definitions

| Term | Definition | Example |
|------|-----------|---------|
| **SLI** (Service Level Indicator) | A measured metric | P99 latency, error rate, uptime % |
| **SLO** (Service Level Objective) | The target for an SLI | P99 latency < 200ms, error rate < 0.1% |
| **SLA** (Service Level Agreement) | Business contract with penalty | 99.9% uptime or $credit, 99.95% or $2× credit |

### ❌ Wrong — No Formal SLOs

```
"SLOs are for SRE teams. Our service is fine."
Reality: Users complain about "slowness." No metric defines what "slow" means.
No error budget. Every incident is a crisis. Teams burn out.
```

### ✅ Expert Fix — SLO-Driven Architecture

```java
// SLO Definition as Code
@ConfigurationProperties("slo.order-service")
public record OrderServiceSLO(
    SLOTarget availability,
    SLOTarget latency,
    SLOTarget errorRate,
    ErrorBudgetPolicy budgetPolicy
) {
    // 99.9% availability = max 43.2 min downtime/month
    public static final OrderServiceSLO PRODUCTION = new OrderServiceSLO(
        new SLOTarget("availability", 99.9, WindowUnit.MONTH),
        new SLOTarget("latency_p99", 200, WindowUnit.MINUTE),  // 200ms
        new SLOTarget("error_rate", 0.1, WindowUnit.MINUTE),   // 0.1%
        ErrorBudgetPolicy.PAUSE_DEPLOYS_ON_EXHAUSTION
    );
}

public record SLOTarget(String name, double threshold, double window, WindowUnit unit) {}

public enum ErrorBudgetPolicy {
    PAUSE_DEPLOYS_ON_EXHAUSTION,   // stop deploys when budget burned
    ALERT_ONLY,                     // warn but don't block
    ENFORCE_STRICTLY                // auto-rollback if budget exceeded
}

// Error Budget Calculator
public class ErrorBudgetCalculator {

    public record ErrorBudgetStatus(
        double budgetRemainingPercent,  // 0-100%
        double burnRatePerHour,         // how fast we're burning
        Duration estimatedExhaustion,   // time until budget exhausted
        boolean shouldPauseDeploys      // architectural gate
    ) {}

    public ErrorBudgetStatus calculate(OrderServiceSLO slo,
            MetricsWindow currentWindow) {

        double totalBudget = 1.0 - (slo.availability().threshold() / 100.0);
        double consumed = currentWindow.downtimeMinutes()
            / currentWindow.totalMinutes();

        double remainingPercent = Math.max(0,
            (totalBudget - consumed) / totalBudget * 100);

        double burnRate = consumed / currentWindow.elapsedHours();
        double hoursUntilExhaustion = burnRate > 0
            ? (totalBudget - consumed) / burnRate : Double.MAX_VALUE;

        boolean pauseDeploys = slo.budgetPolicy() == ErrorBudgetPolicy.PAUSE_DEPLOYS_ON_EXHAUSTION
            && remainingPercent < 5.0;  // < 5% budget left → stop deploys

        return new ErrorBudgetStatus(remainingPercent, burnRate,
            Duration.ofHours((long) hoursUntilExhaustion), pauseDeploys);
    }
}
```

```java
// Deployment gate — integrated with CI-1 canary stage
@Component
public class SLODeploymentGate {
    private final ErrorBudgetCalculator calculator;

    public DeploymentDecision evaluate(OrderServiceSLO slo) {
        var status = calculator.calculateCurrent(slo);

        if (status.shouldPauseDeploys()) {
            return DeploymentDecision.BLOCKED.withReason(
                "Error budget exhausted: %.1f%% remaining. Deploys paused. " +
                "Focus on reliability, not features.", status.budgetRemainingPercent());
        }

        if (status.budgetRemainingPercent() < 20) {
            return DeploymentDecision.ALLOWED_WITH_WARNING.withReason(
                "Error budget low: %.1f%% remaining. " +
                "Consider delaying non-critical deploys.", status.budgetRemainingPercent());
        }

        return DeploymentDecision.ALLOWED;
    }
}
```

**Expert Note**: SLOs are not just for SRE teams — they are architectural constraints. When error budget is exhausted, deploys should STOP. This is not punishment; it's a feedback loop: if the system is unreliable, stop making changes until it's stable. The 99.9% availability SLO (43 min downtime/month) is the industry standard for SaaS. 99.95% (21 min/month) requires automated rollback. 99.99% (4 min/month) requires multi-region active-active — the architecture MUST change to support it.

---

## OB-2: Dashboard Architecture

**Use when**: Designing observability dashboards. A good dashboard tells a story in 5 seconds. A bad one is a data firehose that nobody reads.

### ❌ Wrong — Single Monolith Dashboard

```
Every metric on one dashboard: 200 graphs, 50 rows.
Nobody knows where to look during an incident.
"Scroll down... no, further... the error graph is somewhere..."
```

### ✅ Expert Fix — Layered Dashboard Architecture

```
Dashboard Hierarchy:
  L1 — Executive (1 view, 5 seconds): Global health, SLO status, error budgets
  L2 — Service (per-service, 30 seconds): RED metrics (Rate/Errors/Duration), resources
  L3 — Debug (per-endpoint, on-demand): Traces, logs, thread dumps, heap profiles
```

```java
// Dashboard generation — RED metrics pattern
public record REDMetrics(
    RateMetrics rate,      // requests per second
    ErrorMetrics errors,   // error count + percentage
    DurationMetrics duration // P50, P90, P99 latency
) {
    public enum Health { HEALTHY, DEGRADED, CRITICAL }

    public Health assess(OrderServiceSLO slo) {
        if (errors.percentage() > slo.errorRate().threshold() * 2) return Health.CRITICAL;
        if (duration.p99().toMillis() > slo.latency().threshold()) return Health.DEGRADED;
        return Health.HEALTHY;
    }
}
```

**L1 Executive Dashboard (Grafana example):**
```
┌──────────────────────────────────────────────────────────────┐
│  ██ Platform Health                         Last updated: 2s │
├────────────┬────────────┬────────────┬──────────────────────┤
│ Order Svc  │ Payment Svc│ Inventory  │ Error Budget          │
│ 🟢 99.97%  │ 🟢 99.95%  │ 🟡 99.87% │ ████████░░ 78%       │
├────────────┴────────────┴────────────┴──────────────────────┤
│ P99 Latency: Order 145ms | Payment 320ms | Inventory 890ms  │
│ Active Alerts: 0 Critical | 3 Warning                        │
└──────────────────────────────────────────────────────────────┘
```

**L2 Service Dashboard (per-service):**
```
RED Panel: Rate( RPS ) | Errors( % ) | Duration( P99 ms )
USE Panel: CPU( % )    | Memory( % ) | Disk I/O( MB/s ) | Network( MB/s )
SLO Panel: Current vs Target | Error Budget Burn-down | 7-day Trend
```

**Expert Note**: A dashboard is an architectural artifact. It must answer "Is the system healthy?" in 5 seconds for the L1, 30 seconds for the L2. The RED (Rate/Errors/Duration) pattern applies to EVERY service. The USE (Utilization/Saturation/Errors) pattern applies to EVERY resource. If you can't read the dashboard at a glance, the dashboard is broken, not the service.

---

## OB-3: Alerting Strategy

**Use when**: Designing alerting rules. Alert fatigue is the #1 cause of ignored critical incidents. Every alert must be actionable.

### ❌ Wrong — Alert on Everything

```yaml
# 500 alerts/day. 3 are actionable. On-call ignores all alerts.
# "CPU > 80% for 1 minute" — but CPU spikes are normal during deploys/batch jobs.

alerts:
  - name: high-cpu
    condition: cpu > 80%
    for: 1m                    # too sensitive — alerts on every deploy
  - name: error-rate
    condition: error_rate > 1%
    for: 30s                   # too sensitive — transient network blips alert
  - name: disk-space
    condition: disk_free < 20%
    severity: CRITICAL         # wrong severity — 20% free is hours from critical
```

### ✅ Expert Fix — Symptom-Based, Tiered Severity

```yaml
# Alerting hierarchy: PAGE (wake up) > TICKET (during business hours) > LOG (review later)

# PAGE: CRITICAL — user-facing impact, wake someone up NOW
alerts:
  - name: slo-burn-rate-critical
    description: "SLO burn rate > 10x (will exhaust budget in < 1 hour)"
    condition: burn_rate > 10.0
    for: 5m
    severity: PAGE
    runbook: docs/runbooks/slo-burn-exhaustion.md

  - name: availability-below-threshold
    description: "Service availability < 99.5% (SLO is 99.9%)"
    condition: availability < 99.5
    for: 5m
    severity: PAGE
    runbook: docs/runbooks/service-down.md

  - name: payment-failure-spike
    description: "Payment failure rate > 5% for 5 minutes"
    condition: payment_error_rate > 5.0
    for: 5m
    severity: PAGE              # MONEY = PAGE, always

# TICKET: WARNING — investigate during business hours
  - name: elevated-latency-warning
    description: "P99 latency > SLO threshold for 15 minutes"
    condition: p99_latency > slo_target
    for: 15m
    severity: TICKET

  - name: error-budget-burn-warning
    description: "Error budget < 50% remaining"
    condition: error_budget < 50
    severity: TICKET

  - name: disk-space-trend
    description: "Disk will be full in < 7 days at current rate"
    condition: disk_fill_rate * 168h > disk_free
    severity: TICKET

# LOG: INFO — no action needed, recorded for postmortems
  - name: deployment-completed
    severity: LOG
```

**Alert Severity Decision Matrix:**

| Symptom | Is Revenue Affected? | Is User Affected? | Severity |
|---------|---------------------|-------------------|----------|
| Payment failing | YES | YES | **PAGE** |
| Service down | Possibly | YES | **PAGE** |
| SLO burning fast | Possibly | Possibly | **PAGE** (if critical service) |
| P99 > SLO for 15 min | No | YES (slower) | TICKET |
| Error budget < 50% | No | No (yet) | TICKET |
| Disk trending full | No | No (yet) | TICKET |
| CPU > 80% | No | No | LOG (HPA handles it) |
| Single 500 error | No | 1 user | LOG |

**Expert Note**: The cardinal rule of alerting: **every PAGE must have a runbook**. If the on-call engineer receives a page and their only option is "wake up someone else," the alert is misconfigured. Symptom-based alerting means alerting on what the user experiences (errors, latency), not on causes (CPU, memory). The cause is for debugging; the symptom is for alerting.

---

## OB-4: Distributed Tracing Architecture

**Use when**: Microservices span 5+ services. Without distributed tracing, debugging a slow request is guesswork across service boundaries.

### ❌ Wrong — Log-Based Debugging Across Services

```
"Order timeout — check logs of all 7 services, correlate by timestamp."
7 × grep, 3 different time formats, 2 services not logging request IDs.
Root cause found: 45 minutes. Mean Time To Resolution (MTTR): 45 min.
```

### ✅ Expert Fix — OpenTelemetry Trace Architecture

```java
// Auto-instrumentation (Spring Boot 3 + Micrometer Tracing)
@Configuration
public class TracingConfig {

    @Bean
    public ObservationRegistry observationRegistry() {
        return ObservationRegistry.create();
    }

    // Custom span for critical business logic
    @Bean
    public ObservedAspect observedAspect(ObservationRegistry registry) {
        return new ObservedAspect(registry);
    }
}

// Span annotation — trace critical operations
@Service
public class PaymentService {

    @Observed(name = "payment.charge",
              contextualName = "charge-payment",
              lowCardinalityKeys = {"payment.method", "payment.currency"})
    public PaymentResult charge(PaymentRequest req) {
        // Trace automatically includes: duration, status (ok/error),
        // parent span (from controller), service name, trace ID
        return gateway.charge(req);
    }
}
```

```yaml
# OpenTelemetry Collector — tail sampling (keep 100% errors, 1% normal)
receivers:
  otlp:
    protocols:
      grpc: {}
      http: {}

processors:
  tail_sampling:
    decision_wait: 10s       # wait for span completion before deciding
    policies:
      - name: errors-only
        type: status_code
        status_code:
          status_codes: [ERROR]        # 100% ERROR traces
      - name: latency-threshold
        type: latency
        latency:
          threshold_ms: 500            # 100% slow traces (>500ms)
      - name: payment-traces
        type: string_attribute
        string_attribute:
          key: service.name
          values: ["payment-service"]  # 100% payment traces (reconciliation)
      - name: probabilistic
        type: probabilistic
        probabilistic:
          sampling_percentage: 1.0     # 1% normal traffic

exporters:
  otlp/jaeger:
    endpoint: jaeger:4317
    tls:
      insecure: true

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [tail_sampling]
      exporters: [otlp/jaeger]
```

**Trace Waterfall (what the architect sees):**
```
GET /orders/12345                    [ 845ms total ]
├── auth-service/validate-token      [  12ms ✅ ]
├── order-service/get-order          [  45ms ✅ ]
├── inventory-service/check-stock    [ 320ms ⚠️  ]  ← WHY?
│   └── postgres/query-stock         [ 310ms 🔴  ]  ← ROOT CAUSE
├── payment-service/charge           [ 180ms ✅ ]
└── notification-service/send-email  [  88ms ✅ ]

Diagnosis: inventory DB query missing index → 310ms per query
Fix: CREATE INDEX + re-deploy = 128ms → total 845ms drops to 335ms
Time to find: 5 seconds (trace) vs 45 minutes (log grep). 540× faster.
```

**Expert Note**: Distributed tracing transforms MTTR from "find the needle in 7 haystacks" to "click the red span." The sampling architecture is critical: tail sampling (decide after span completes) allows rules like "keep 100% errors + 100% slow + 1% normal." Head sampling (decide at span start) is simpler but can't retroactively keep slow traces. For payment services, 100% sampling is appropriate — reconciliation requires every transaction.

---

## OB-5: Structured Logging Architecture

**Use when**: Logs are consumed by machines (log aggregators, SIEM, alerting), not just humans. Structured logs enable search and correlation.

### ❌ Wrong — Unstructured, Inconsistent Logs

```
2026-05-15 14:23:45 Order 12345 processed successfully
ERROR: something went wrong with payment 67890
User 999 logged in

Problem: No consistent format. Can't query "show all ERROR logs for payment service."
Can't correlate by traceId. Can't compute error rate from logs.
```

### ✅ Expert Fix — Structured JSON Logging with Correlation

```xml
<!-- logback-spring.xml — structured JSON -->
<appender name="JSON" class="ch.qos.logback.core.ConsoleAppender">
    <encoder class="net.logstash.logback.encoder.LogstashEncoder">
        <includeContext>false</includeContext>
        <fieldNames>
            <timestamp>@timestamp</timestamp>
            <version>[ignore]</version>
        </fieldNames>
        <customFields>
            {"service":"${SERVICE_NAME:-unknown}",
             "environment":"${ENVIRONMENT:-dev}",
             "version":"${APP_VERSION:-unknown}"}
        </customFields>
    </encoder>
</appender>
```

```json
// Structured log output
{
  "@timestamp": "2026-05-15T14:23:45.123Z",
  "service": "order-service",
  "environment": "production",
  "version": "3.2.1",
  "level": "INFO",
  "traceId": "a1b2c3d4e5f67890",
  "spanId": "1234567890abcdef",
  "message": "Order processed",
  "orderId": "12345",
  "userId": "999",
  "durationMs": 45,
  "status": "SUCCESS"
}
```

```java
// Structured logging in code — Mapped Diagnostic Context (MDC)
@Slf4j
@Service
public class OrderService {

    public OrderResult process(OrderRequest req) {
        MDC.put("orderId", req.orderId());
        MDC.put("userId", req.userId());

        var start = System.currentTimeMillis();
        try {
            var result = doProcess(req);
            MDC.put("durationMs", String.valueOf(System.currentTimeMillis() - start));
            MDC.put("status", "SUCCESS");
            log.info("Order processed"); // automatically includes MDC fields
            return result;
        } catch (Exception e) {
            MDC.put("durationMs", String.valueOf(System.currentTimeMillis() - start));
            MDC.put("status", "FAILED");
            MDC.put("errorType", e.getClass().getSimpleName());
            log.error("Order processing failed", e);
            throw e;
        } finally {
            MDC.clear(); // ALWAYS clear — thread pool reuse leaks MDC
        }
    }
}
```

**Log Query Power (ELK / Splunk / Loki):**
```
Before (unstructured):  grep "ERROR" *.log  → manual, slow, no stats
After (structured):
  - level:ERROR AND service:payment-service  → all payment errors in 50ms
  - traceId:a1b2c3* AND level:ERROR          → ALL errors in a trace chain
  - level:ERROR | stats count BY service     → error rate per service, auto-updated
```

**Expert Note**: Structured logging is not "fancy format" — it's architectural enablement. When every log line has `traceId`, you can reconstruct an entire request's lifecycle across 7 services in a single query. The `MDC.clear()` in `finally` is not optional — in thread-pooled environments (Tomcat), uncleared MDC leaks context between unrelated requests, creating phantom correlations that waste hours of debugging.

---

## Quick Observability Checklist

- [ ] SLI defined per service (availability, latency, error rate)?
- [ ] SLO targets documented: 99.9% availability, P99 < X ms, error < Y%?
- [ ] Error budget policy established (pause deploys on exhaustion)?
- [ ] L1 Executive Dashboard answers "healthy?" in 5 seconds?
- [ ] RED metrics (Rate/Errors/Duration) on every service dashboard?
- [ ] Every PAGE alert has a documented runbook (not "wake up someone else")?
- [ ] Alert fatigue monitored (target: < 10 pages/week)?
- [ ] Distributed tracing: 100% errors, 100% slow (>500ms), 1% normal?
- [ ] Payment/revenue-critical services: 100% tracing (reconciliation)?
- [ ] Structured JSON logging with traceId + spanId in every line?
- [ ] MDC always cleared in finally block (thread pool leak prevention)?
- [ ] Log retention policy defined (OB → log policy, not "keep forever")?
