# Observability & Monitoring Standards

## Overview

This document defines observability standards for migrated COBOL-to-Java applications, covering metrics, tracing, logging, and alerting. The goal is to achieve parity with — and eventually surpass — mainframe monitoring capabilities (SMF records, RMF reports, CICS PA).

## Metrics: Micrometer Standard Tags

### Required Standard Tags

```java
@Configuration
public class MicrometerConfig {

    @Bean
    public MeterRegistryCustomizer<MeterRegistry> commonTags() {
        return registry -> registry.config().commonTags(
            "service", "${spring.application.name}",
            "version", "${app.version:unknown}",
            "environment", "${app.env:dev}",
            "datacenter", "${app.datacenter:default}",
            "team", "${app.team:platform}",
            "cobol_program_id", "${app.cobol_program_id:none}"
        );
    }
}
```

### Key Business Metrics

| Metric Name | Type | Labels | Description |
|------------|------|--------|-------------|
| `transaction_count_total` | Counter | `txn_type`, `channel`, `result` | Total transactions processed |
| `transaction_duration_seconds` | Timer / Summary | `txn_type`, `channel` | Transaction processing latency |
| `transaction_amount_total` | Counter | `txn_type`, `currency` | Monetary transaction value sum |
| `authentication_attempts_total` | Counter | `provider`, `result` | Auth success/failure count |
| `business_validation_failures_total` | Counter | `rule_code`, `program_id` | Business validation failures |
| `daily_processing_records_total` | Counter | `job_name`, `step_name` | Batch processing volume |
| `error_transaction_count_total` | Counter | `error_code`, `program_id` | Error transactions count |

### Business Metrics Implementation

```java
@Component
public class BusinessMetrics {

    private final MeterRegistry registry;

    public BusinessMetrics(MeterRegistry registry) {
        this.registry = registry;
    }

    public Counter transactionCount(String txnType, String channel, String result) {
        return Counter.builder("transaction_count_total")
            .tag("txn_type", txnType)
            .tag("channel", channel)
            .tag("result", result)
            .register(registry);
    }

    public void recordTransaction(String txnType, String channel, long durationMs,
                                   BigDecimal amount, boolean success) {
        transactionCount(txnType, channel, success ? "SUCCESS" : "FAILURE").increment();

        Timer.builder("transaction_duration_seconds")
            .tag("txn_type", txnType)
            .tag("channel", channel)
            .register(registry)
            .record(durationMs, TimeUnit.MILLISECONDS);

        if (amount != null) {
            Counter.builder("transaction_amount_total")
                .tag("txn_type", txnType)
                .tag("currency", "JPY")
                .register(registry)
                .increment(amount.doubleValue());
        }
    }
}
```

### JVM Metrics

```yaml
management:
  metrics:
    enable:
      jvm: true
      process: true
      system: true
    tags:
      application: ${spring.application.name}
```

| JVM Metric | Description | Alert Threshold |
|-----------|-------------|-----------------|
| `jvm.memory.used` | Heap memory used | > 85% of max |
| `jvm.memory.committed` | Heap committed | — |
| `jvm.gc.pause` | GC pause time | P99 > 200ms |
| `jvm.gc.memory.promoted` | Promotion rate | > 50MB/s |
| `jvm.threads.live` | Live thread count | > 500 |
| `jvm.threads.states` | Threads by state | BLOCKED > 10 |

### DB Connection Pool Metrics

```java
@Component
public class DbPoolMetrics {

    @EventListener
    public void bindMetrics(HikariDataSource dataSource, MeterRegistry registry) {
        HikariPoolMXBean pool = dataSource.getHikariPoolMXBean();
        if (pool == null) return;

        Gauge.builder("hikari.active_connections", pool, HikariPoolMXBean::getActiveConnections)
            .register(registry);
        Gauge.builder("hikari.idle_connections", pool, HikariPoolMXBean::getIdleConnections)
            .register(registry);
        Gauge.builder("hikari.pending_threads", pool, HikariPoolMXBean::getThreadsAwaitingConnection)
            .register(registry);
        Gauge.builder("hikari.total_connections", pool, HikariPoolMXBean::getTotalConnections)
            .register(registry);
    }
}
```

## Grafana Dashboard

### Business KPIs Dashboard JSON Skeleton

```json
{
  "dashboard": {
    "uid": "cobol-migration-kpi",
    "title": "COBOL Migration — Business KPIs",
    "tags": ["cobol-migration", "business-kpi"],
    "timezone": "browser",
    "schemaVersion": 38,
    "panels": [
      {
        "id": 1,
        "title": "Transaction Volume",
        "type": "bargauge",
        "targets": [
          {
            "expr": "rate(transaction_count_total[5m])",
            "legendFormat": "{{txn_type}} — {{result}}"
          }
        ]
      },
      {
        "id": 2,
        "title": "P95 Transaction Latency",
        "type": "timeseries",
        "targets": [
          {
            "expr": "histogram_quantile(0.95, sum(rate(transaction_duration_seconds_bucket[5m])) by (le, txn_type))",
            "legendFormat": "P95 — {{txn_type}}"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "s",
            "thresholds": {
              "steps": [
                {"color": "green", "value": null},
                {"color": "yellow", "value": 0.5},
                {"color": "red", "value": 2.0}
              ]
            }
          }
        }
      },
      {
        "id": 3,
        "title": "Error Rate",
        "type": "timeseries",
        "targets": [
          {
            "expr": "sum(rate(transaction_count_total{result=\"FAILURE\"}[5m])) / sum(rate(transaction_count_total[5m])) * 100",
            "legendFormat": "Error Rate %"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "percent",
            "thresholds": {
              "steps": [
                {"color": "green", "value": null},
                {"color": "red", "value": 1.0}
              ]
            }
          }
        }
      },
      {
        "id": 4,
        "title": "Authentication Activity",
        "type": "timeseries",
        "targets": [
          {
            "expr": "rate(authentication_attempts_total{result=\"SUCCESS\"}[5m])",
            "legendFormat": "Success"
          },
          {
            "expr": "rate(authentication_attempts_total{result=\"FAILURE\"}[5m])",
            "legendFormat": "Failure"
          }
        ]
      },
      {
        "id": 5,
        "title": "Daily Processing Volume",
        "type": "stat",
        "targets": [
          {
            "expr": "increase(daily_processing_records_total[24h])",
            "legendFormat": "Total Records"
          }
        ]
      }
    ]
  }
}
```

### Technical Health Dashboard Description

| Panel | Metric | Visualization | Thresholds |
|-------|--------|--------------|------------|
| JVM Heap Usage | `jvm_memory_used_bytes{area="heap"} / jvm_memory_max_bytes{area="heap"}` | Gauge | Green < 70%, Yellow < 85%, Red > 90% |
| GC Pause Time | `rate(jvm_gc_pause_seconds_sum[5m])` | Timeseries | Yellow > 100ms, Red > 200ms |
| Thread States | `jvm_threads_states_threads` | Stacked bar | BLOCKED > 10 alert |
| DB Active Connections | `hikari_active_connections` | Timeseries | Green < 60%, Yellow < 80%, Red > 90% |
| HTTP Request Rate | `rate(http_server_requests_seconds_count[5m])` | Timeseries | — |
| HTTP Error Rate | `rate(http_server_requests_seconds_count{status=~"5.."}[5m]) / rate(...)` | Timeseries | Red > 1% |
| CPU Usage | `system_cpu_usage` | Timeseries | Red > 80% sustained |
| Disk Usage | `disk_free_bytes / disk_total_bytes` | Gauge | Yellow < 20% free, Red < 10% free |

## Tracing: Spring Cloud Sleuth / Micrometer Tracing

### Dependency Configuration (pom.xml)

```xml
<dependency>
    <groupId>io.micrometer</groupId>
    <artifactId>micrometer-tracing-bridge-brave</artifactId>
</dependency>
<dependency>
    <groupId>io.zipkin.reporter2</groupId>
    <artifactId>zipkin-reporter-brave</artifactId>
</dependency>
```

### application.yml Tracing Configuration

```yaml
spring:
  application:
    name: cobol-inquiry-service
management:
  tracing:
    sampling:
      probability: 0.1
    baggage:
      remote-fields:
        - cobol_program_id
        - correlation_id
        - user_id
        - channel_type
      correlation:
        fields:
          - cobol_program_id
          - correlation_id
          - user_id
  zipkin:
    tracing:
      endpoint: http://zipkin:9411/api/v2/spans

logging:
  pattern:
    level: "%5p [${spring.application.name:},%X{traceId:-},%X{spanId:-}]"
```

### Trace Propagation Across Services

```java
@Configuration
public class TracingConfig {

    @Bean
    public RestTemplate restTemplate(RestTemplateBuilder builder) {
        return builder.build();
    }

    @Bean
    public WebClient webClient() {
        return WebClient.builder()
            .filter(new TraceExchangeFilterFunction())
            .build();
    }
}

@Component
public class TraceHeaderPropagator implements HandlerInterceptor {

    private final Tracer tracer;

    public TraceHeaderPropagator(Tracer tracer) {
        this.tracer = tracer;
    }

    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response,
                              Object handler) {
        BaggageField.getByName("cobol_program_id")
            .updateValue(request.getHeader("X-Cobol-Program-Id"));
        BaggageField.getByName("correlation_id")
            .updateValue(request.getHeader("X-Correlation-Id"));
        return true;
    }
}
```

### Correlation ID → COBOL Program ID Mapping

```java
@Component
public class CobolTraceMapping {

    private final Tracer tracer;

    public CobolTraceMapping(Tracer tracer) {
        this.tracer = tracer;
    }

    public void setCobolContext(String cobolProgramId, String transactionId) {
        BaggageField.getByName("cobol_program_id").updateValue(cobolProgramId);
        Span currentSpan = tracer.currentSpan();
        if (currentSpan != null) {
            currentSpan.tag("cobol.program_id", cobolProgramId);
            currentSpan.tag("cobol.transaction_id", transactionId);
        }
    }

    public void addBusinessTag(String key, String value) {
        Span currentSpan = tracer.currentSpan();
        if (currentSpan != null) {
            currentSpan.tag("business." + key, value);
        }
    }
}
```

## Alerting

### Alert Rule Templates

```yaml
# prometheus-rules.yaml
groups:
  - name: cobol_migration_alerts
    interval: 30s
    rules:
      - alert: HighErrorRate
        expr: |
          sum(rate(transaction_count_total{result="FAILURE"}[5m]))
          / sum(rate(transaction_count_total[5m])) > ${ERROR_RATE_ALERT}
        for: 5m
        labels:
          severity: P1
          team: cobol-migration
        annotations:
          summary: "Error rate exceeds ${ERROR_RATE_ALERT}%"
          description: "Error rate is {{ $value | humanizePercentage }} over 5min"
          runbook: "https://wiki.internal/cobol-migration/alerts#high-error-rate"

      - alert: HighLatency
        expr: |
          histogram_quantile(0.99,
            sum(rate(transaction_duration_seconds_bucket[5m])) by (le, txn_type)
          ) > ${P99_THRESHOLD}
        for: 5m
        labels:
          severity: P1
          team: cobol-migration
        annotations:
          summary: "P99 latency exceeds ${P99_THRESHOLD}s"
          description: "{{ $labels.txn_type }} P99 = {{ $value }}s"
          runbook: "https://wiki.internal/cobol-migration/alerts#high-latency"

      - alert: DatabaseConnectionPoolExhaustion
        expr: |
          hikari_pending_threads / hikari_total_connections > 0.8
        for: 2m
        labels:
          severity: P2
        annotations:
          summary: "DB connection pool > 80% exhausted"
          description: "{{ $value | humanizePercentage }} pending ratio"

      - alert: HighDiskUsage
        expr: |
          (1 - disk_free_bytes{job="node_exporter"} / disk_total_bytes{job="node_exporter"}) > 0.85
        for: 10m
        labels:
          severity: P2
        annotations:
          summary: "Disk usage > 85%"

      - alert: JvmMemoryHigh
        expr: |
          jvm_memory_used_bytes{area="heap"}
          / jvm_memory_max_bytes{area="heap"} > 0.85
        for: 5m
        labels:
          severity: P2
        annotations:
          summary: "JVM heap > 85%"

      - alert: ServiceDown
        expr: up == 0
        for: 1m
        labels:
          severity: P0
        annotations:
          summary: "Service {{ $labels.job }} is down"
```

### Prometheus AlertManager Configuration

```yaml
# alertmanager.yml
global:
  resolve_timeout: 5m
  slack_api_url: "${SLACK_WEBHOOK_URL}"

route:
  group_by: ['alertname', 'severity']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h
  receiver: 'default'
  routes:
    - match:
        severity: P0
      receiver: 'p0-oncall'
      repeat_interval: 5m
    - match:
        severity: P1
      receiver: 'p1-team'
    - match:
        severity: P2
      receiver: 'slack-alerts'
    - match:
        severity: P3
      receiver: 'email-team'
    - match:
        severity: P4
      receiver: 'email-team'

receivers:
  - name: 'default'
    slack_configs:
      - channel: '#cobol-migration-alerts'
        title: '{{ .GroupLabels.alertname }}'
        text: '{{ .CommonAnnotations.description }}'

  - name: 'p0-oncall'
    pagerduty_configs:
      - routing_key: '${PAGERDUTY_KEY}'
    slack_configs:
      - channel: '#oncall-critical'

  - name: 'p1-team'
    slack_configs:
      - channel: '#cobol-migration-alerts'

  - name: 'slack-alerts'
    slack_configs:
      - channel: '#cobol-migration-info'

  - name: 'email-team'
    email_configs:
      - to: 'cobol-migration-team@internal.com'
```

### Alert Severity Classification

| Level | Name | Response Time | Escalation | Examples |
|-------|------|--------------|------------|----------|
| P0 | Critical | 15 min | Auto-page on-call | Service down, complete outage |
| P1 | High | 30 min | Slack + on-call rotation | Error rate > 5%, latency > 5s 99th |
| P2 | Medium | 2 hours | Slack channel | DB pool > 80%, disk > 85% |
| P3 | Low | Next business day | Slack channel | Disk > 75%, CPU > 70% sustained |
| P4 | Informational | Next sprint | Email digest | Deprecated API usage, minor anomalies |

## Structured Logging

### JSON Log Format Specification

```json
{
  "timestamp": "2026-05-04T10:30:00.123Z",
  "level": "INFO",
  "logger": "com.example.migration.service.InquiryService",
  "service": "cobol-inquiry-service",
  "environment": "production",
  "traceId": "5b3c4d5e6f7a8b9c",
  "spanId": "1a2b3c4d5e6f",
  "userId": "USER01",
  "cobolProgramId": "INQ0001",
  "correlationId": "CORR-20260504-001234",
  "message": "Customer inquiry completed",
  "durationMs": 45,
  "resultCode": "SUCCESS",
  "customerId": "CUST-12345",
  "exception": null
}
```

### Required Log Fields

| Field | Mapped From | Required | Format |
|-------|------------|----------|--------|
| `timestamp` | System clock | Yes | ISO-8601 with millis |
| `level` | SLF4J level | Yes | DEBUG/INFO/WARN/ERROR |
| `logger` | Class name | Yes | Fully qualified |
| `service` | `spring.application.name` | Yes | kebab-case |
| `environment` | `app.env` | Yes | dev/staging/prod |
| `traceId` | Micrometer Tracing | Yes (prod) | 16-char hex |
| `spanId` | Micrometer Tracing | Yes (prod) | 16-char hex |
| `userId` | SecurityContext | When authenticated | RACF USERID format |
| `cobolProgramId` | Baggage field | Optional | COBOL program name |
| `correlationId` | Request header | Optional | Business correlation ID |
| `message` | Log message | Yes | Human-readable |
| `durationMs` | Timer sample | For timed ops | Number |

### Logback JSON Configuration

```xml
<!-- logback-spring.xml -->
<configuration>
    <appender name="JSON_CONSOLE" class="ch.qos.logback.core.ConsoleAppender">
        <encoder class="net.logstash.logback.encoder.LogstashEncoder">
            <includeMdcKeyName>traceId</includeMdcKeyName>
            <includeMdcKeyName>spanId</includeMdcKeyName>
            <includeMdcKeyName>userId</includeMdcKeyName>
            <includeMdcKeyName>cobolProgramId</includeMdcKeyName>
            <includeMdcKeyName>correlationId</includeMdcKeyName>
            <fieldNames>
                <timestamp>timestamp</timestamp>
                <version>[ignore]</version>
                <levelValue>[ignore]</levelValue>
            </fieldNames>
        </encoder>
    </appender>

    <root level="INFO">
        <appender-ref ref="JSON_CONSOLE"/>
    </root>
</configuration>
```

### MDC Context Propagation

```java
@Component
public class LoggingContextFilter extends OncePerRequestFilter {

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                     HttpServletResponse response,
                                     FilterChain filterChain)
            throws ServletException, IOException {
        try {
            String userId = extractUserId(request);
            String cobolProgramId = request.getHeader("X-Cobol-Program-Id");
            String correlationId = request.getHeader("X-Correlation-Id");

            if (userId != null) MDC.put("userId", userId);
            if (cobolProgramId != null) MDC.put("cobolProgramId", cobolProgramId);
            if (correlationId != null) MDC.put("correlationId", correlationId);

            filterChain.doFilter(request, response);
        } finally {
            MDC.clear();
        }
    }

    private String extractUserId(HttpServletRequest request) {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        return auth != null && auth.isAuthenticated() ? auth.getName() : null;
    }
}
```

### MDC Context in Async Operations

```java
@Configuration
public class AsyncMdcConfig implements AsyncConfigurer {

    @Override
    public Executor getAsyncExecutor() {
        ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
        executor.setCorePoolSize(5);
        executor.setMaxPoolSize(10);
        executor.setQueueCapacity(100);

        executor.setTaskDecorator(runnable -> {
            Map<String, String> contextMap = MDC.getCopyOfContextMap();
            return () -> {
                try {
                    if (contextMap != null) MDC.setContextMap(contextMap);
                    runnable.run();
                } finally {
                    MDC.clear();
                }
            };
        });

        executor.initialize();
        return executor;
    }
}
```

## Complete application.yml Observability Configuration

```yaml
spring:
  application:
    name: cobol-${SERVICE_NAME}
  sleuth:
    baggage:
      remote-fields:
        - cobol_program_id
        - correlation_id
        - user_id
      correlation-fields:
        - cobol_program_id
        - correlation_id
        - user_id

management:
  endpoints:
    web:
      exposure:
        include: health,info,prometheus,metrics,loggers,env
  endpoint:
    health:
      show-details: always
      probes:
        enabled: true
      group:
        readiness:
          include: readinessState,db
        liveness:
          include: livenessState
  metrics:
    tags:
      application: ${spring.application.name}
      environment: ${app.env:dev}
    export:
      prometheus:
        enabled: true
        step: 30s
    distribution:
      percentiles-histogram:
        http.server.requests: true
        transaction_duration_seconds: true
      percentiles:
        http.server.requests: 0.5,0.95,0.99
  tracing:
    sampling:
      probability: ${TRACING_SAMPLE_RATE:0.1}
    baggage:
      remote-fields:
        - cobol_program_id
        - correlation_id

logging:
  level:
    root: INFO
    com.example.migration: ${LOG_LEVEL:INFO}
    org.springframework.security: WARN
    org.hibernate.SQL: ${SQL_LOG_LEVEL:WARN}
  pattern:
    correlation: "[${spring.application.name:},%X{traceId:-},%X{spanId:-},%X{userId:-}]"
```

## Integration Notes

- Referenced by: quality-checklist.md checks 1-30 (monitoring verification), SKILL.md Phase 10h (Performance benchmarking), performance-sla-templates.md (SLA metric definitions), production-patterns.md (production readiness)
- Last reviewed: 2026-05-04
