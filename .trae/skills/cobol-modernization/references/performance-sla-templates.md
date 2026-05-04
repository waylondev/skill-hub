# Performance SLA Templates

## Overview

This document provides standardized SLA (Service Level Agreement) templates for comparing COBOL mainframe performance against migrated Java cloud applications. All variable fields use `${VAR_NAME}` syntax for easy substitution per project.

## OLTP SLA Template

```yaml
# oltp-sla.yaml — Online Transaction Processing SLA
application: ${APP_NAME}
environment: ${ENV}
service_type: OLTP
effective_date: ${EFFECTIVE_DATE}
review_frequency: quarterly

latency_targets:
  P50_latency_ms:
    target: ${P50_TARGET}
    unit: milliseconds
    measurement_window: 1_minute_rolling
  P95_latency_ms:
    target: ${P95_TARGET}
    unit: milliseconds
    measurement_window: 1_minute_rolling
    alert_threshold: ${P95_TARGET} * 1.2
  P99_latency_ms:
    target: ${P99_TARGET}
    unit: milliseconds
    measurement_window: 1_minute_rolling
    alert_threshold: ${P99_TARGET} * 1.5

throughput_targets:
  requests_per_second:
    target: ${MIN_QPS}
    unit: requests_per_second
    measurement_window: 1_minute_sustained
    degradation_threshold: ${MIN_QPS} * 0.8

reliability_targets:
  error_rate_percent:
    target: ${ERROR_RATE}
    unit: percentage
    measurement_window: 5_minute_rolling
    excludes: [4xx_client_errors]
  availability_percent:
    target: ${AVAILABILITY}
    unit: percentage
    measurement_period: monthly

concurrency_targets:
  max_concurrent_users:
    target: ${MIN_CONCURRENT}
    unit: concurrent_connections
    measurement_window: peak_hour

recovery_targets:
  RTO_seconds: ${RTO}
  RPO_seconds: ${RPO}
```

### OLTP Example: Banking Lookup Service

```yaml
application: CUST-INQUIRY
environment: production
service_type: OLTP
effective_date: 2026-05-01

latency_targets:
  P50_latency_ms: 50
  P95_latency_ms: 150
  P99_latency_ms: 500

throughput_targets:
  requests_per_second: 500

reliability_targets:
  error_rate_percent: 0.1
  availability_percent: 99.95

concurrency_targets:
  max_concurrent_users: 2000

recovery_targets:
  RTO_seconds: 120
  RPO_seconds: 5
```

## Batch SLA Template

```yaml
# batch-sla.yaml — Batch Processing SLA
application: ${APP_NAME}
environment: ${ENV}
service_type: BATCH
effective_date: ${EFFECTIVE_DATE}

batch_window:
  total_window_minutes: ${BATCH_WINDOW_MIN}
  start_time: ${BATCH_START_TIME}
  end_time: ${BATCH_END_TIME}
  critical_path_minutes: ${CRITICAL_PATH_MIN}

throughput_targets:
  records_per_second_min: ${MIN_RPS}
  peak_records_per_second: ${PEAK_RPS}
  measurement_window: per_job_execution

quality_targets:
  error_skip_rate_percent: ${SKIP_RATE}
  data_completeness_percent: ${DATA_COMPLETENESS}

job_level_slas:
${JOB_SLA_TABLE}
```

### Batch Example: End-of-Day Settlement

```yaml
application: EOD-SETTLEMENT
environment: production
service_type: BATCH
effective_date: 2026-05-01

batch_window:
  total_window_minutes: 240
  start_time: "22:00"
  end_time: "02:00"
  critical_path_minutes: 180

throughput_targets:
  records_per_second_min: 10000
  peak_records_per_second: 25000

quality_targets:
  error_skip_rate_percent: 0.01
  data_completeness_percent: 99.99

job_level_slas:
  - job_name: EXTRACT-TRANSACTIONS
    max_duration_minutes: 30
    dependency: NONE
    restartable: true
    parallelism: 4
  - job_name: VALIDATE-TRANSACTIONS
    max_duration_minutes: 45
    dependency: EXTRACT-TRANSACTIONS
    restartable: true
    parallelism: 8
  - job_name: CALCULATE-POSITIONS
    max_duration_minutes: 60
    dependency: VALIDATE-TRANSACTIONS
    restartable: true
    parallelism: 4
  - job_name: GENERATE-REPORTS
    max_duration_minutes: 30
    dependency: CALCULATE-POSITIONS
    restartable: false
    parallelism: 2
  - job_name: ARCHIVE-DATA
    max_duration_minutes: 15
    dependency: GENERATE-REPORTS
    restartable: true
    parallelism: 2
```

### Individual Job SLA Table Template

| Job Name | Max Duration (min) | Depends On | Restartable | Parallelism | Critical Path |
|----------|-------------------|------------|-------------|-------------|---------------|
| `${JOB_1_NAME}` | `${JOB_1_DUR}` | `${JOB_1_DEP}` | `${JOB_1_RESTART}` | `${JOB_1_PARALLEL}` | `${JOB_1_CRITICAL}` |
| `${JOB_2_NAME}` | `${JOB_2_DUR}` | `${JOB_2_DEP}` | `${JOB_2_RESTART}` | `${JOB_2_PARALLEL}` | `${JOB_2_CRITICAL}` |

## Resource Quota Template

```yaml
# resource-quota.yaml — Container Resource Allocation
application: ${APP_NAME}
environment: ${ENV}

services:
${SERVICE_RESOURCES}
```

### Resource Allocation Table Template

| Service | CPU Request | CPU Limit | Memory Request | Memory Limit | JVM Heap | DB Pool Min | DB Pool Max |
|---------|------------|-----------|---------------|-------------|----------|------------|------------|
| `${SVC_1}` | `${CPU_REQ_1}` | `${CPU_LIM_1}` | `${MEM_REQ_1}` | `${MEM_LIM_1}` | `${HEAP_1}` | `${DB_MIN_1}` | `${DB_MAX_1}` |
| `${SVC_2}` | `${CPU_REQ_2}` | `${CPU_LIM_2}` | `${MEM_REQ_2}` | `${MEM_LIM_2}` | `${HEAP_2}` | `${DB_MIN_2}` | `${DB_MAX_2}` |

### Resource Sizing Guidelines

```java
public class ResourceSizingCalculator {

    public static JvmHeapConfig calculateJvmHeap(long expectedLiveDataMB, int concurrentRequests) {
        long heapSize = expectedLiveDataMB
            + (concurrentRequests * 2L)   // 2MB per concurrent request
            + 256;                         // base overhead
        return new JvmHeapConfig(
            " -Xms" + (heapSize / 2) + "m"
            + " -Xmx" + heapSize + "m"
            + " -XX:MaxMetaspaceSize=256m"
            + " -XX:+UseG1GC"
            + " -XX:MaxGCPauseMillis=200"
        );
    }

    public static DbPoolConfig calculateDbPool(int concurrentRequests, int avgQueryMs) {
        int poolSize = (int) Math.ceil(
            concurrentRequests * (avgQueryMs / 1000.0) * 1.3
        );
        return new DbPoolConfig(
            Math.max(5, poolSize / 2),
            Math.max(10, poolSize)
        );
    }

    public record JvmHeapConfig(String javaOpts) {}
    public record DbPoolConfig(int minIdle, int maxPoolSize) {}
}
```

### Resource Example: Spring Boot Deployment

```yaml
services:
  - name: customer-service
    cpu_request: "500m"
    cpu_limit: "2000m"
    memory_request: "1Gi"
    memory_limit: "2Gi"
    jvm_heap: "-Xms512m -Xmx1024m"
    db_pool_min: 5
    db_pool_max: 20
    replicas: 3
    hpa:
      min_replicas: 3
      max_replicas: 10
      cpu_target: 70

  - name: transaction-service
    cpu_request: "1000m"
    cpu_limit: "4000m"
    memory_request: "2Gi"
    memory_limit: "4Gi"
    jvm_heap: "-Xms1024m -Xmx2048m"
    db_pool_min: 10
    db_pool_max: 50
    replicas: 5
    hpa:
      min_replicas: 5
      max_replicas: 20
      cpu_target: 70
```

### DB Connection Pool Sizing

```java
@Configuration
public class DatabasePoolConfig {

    @Bean
    public DataSource dataSource(@Value("${db.url}") String url,
                                  @Value("${db.username}") String username,
                                  @Value("${db.password}") String password,
                                  @Value("${db.pool.min-idle:5}") int minIdle,
                                  @Value("${db.pool.max-size:20}") int maxSize) {
        HikariConfig config = new HikariConfig();
        config.setJdbcUrl(url);
        config.setUsername(username);
        config.setPassword(password);
        config.setMinimumIdle(minIdle);
        config.setMaximumPoolSize(maxSize);
        config.setConnectionTimeout(5000);
        config.setIdleTimeout(300000);
        config.setMaxLifetime(600000);
        config.setLeakDetectionThreshold(30000);
        return new HikariDataSource(config);
    }
}
```

## Comparison Methodology: COBOL Mainframe vs Java Cloud Metrics

### Metric Normalization

| Mainframe Metric | Cloud Equivalent | Conversion Factor |
|-----------------|-----------------|-------------------|
| 1 MIPS | 1 vCPU core (approximate) | ~1 vCPU per 100 MIPS (batch), ~50 MIPS (OLTP) |
| I/O channel bandwidth | Disk IOPS | 1 channel path ≈ 5000-10000 IOPS |
| Mainframe CPU seconds | vCPU seconds | 1 mainframe CPU-sec ≈ 1.2-1.5 vCPU-sec |
| CICS transaction rate | HTTP requests/sec | 1 CICS txn ≈ 1 HTTP request (adjusted for commarea) |
| VSAM I/O per transaction | DB queries per request | 1 VSAM READ ≈ 1 SELECT query |
| Batch elapsed time | Spring Batch duration | Direct comparison (same unit) |
| Mainframe memory (MB) | JVM heap (MB) | COBOL working storage ≈ 10-20% of JVM heap requirement |
| 3270 screen response | API response time | Network difference: +10-30ms for web |

### Comparison Template

```yaml
benchmark_comparison:
  application: ${APP_NAME}
  test_date: ${TEST_DATE}

  mainframe_baseline:
    txn_per_second: ${MAINFRAME_TPS}
    avg_response_ms: ${MAINFRAME_AVG_RESP}
    P95_response_ms: ${MAINFRAME_P95_RESP}
    cpu_usage_percent: ${MAINFRAME_CPU}
    memory_mb: ${MAINFRAME_MEMORY}
    io_per_second: ${MAINFRAME_IO}

  java_cloud_target:
    txn_per_second: ${JAVA_TPS}
    avg_response_ms: ${JAVA_AVG_RESP}
    P95_response_ms: ${JAVA_P95_RESP}
    cpu_usage_percent: ${JAVA_CPU}
    memory_mb: ${JAVA_MEMORY}
    io_per_second: ${JAVA_IO}

  equivalence_ratio:
    throughput: ${JAVA_TPS} / ${MAINFRAME_TPS}
    latency: ${JAVA_AVG_RESP} / ${MAINFRAME_AVG_RESP}
    resource_efficiency: ${JAVA_TPS / JAVA_CPU} / ${MAINFRAME_TPS / MAINFRAME_CPU}
```

### Performance Test Comparison Code

```java
@Service
public class PerformanceComparisonService {

    public ComparisonReport compare(MainframeMetrics baseline, CloudMetrics target) {
        double throughputRatio = target.requestsPerSecond() / baseline.requestsPerSecond();
        double latencyRatio = target.p95ResponseMs() / baseline.p95ResponseMs();
        double cpuEfficiency = (target.requestsPerSecond() / target.cpuCores())
            / (baseline.requestsPerSecond() / (baseline.mips() / 100.0));

        return new ComparisonReport(
            throughputRatio >= 1.0,
            latencyRatio <= 1.5,
            cpuEfficiency >= 0.8,
            throughputRatio,
            latencyRatio,
            cpuEfficiency
        );
    }

    public record MainframeMetrics(double requestsPerSecond, double p95ResponseMs,
                                     double mips, double memoryMB, double ioPerSecond) {}
    public record CloudMetrics(double requestsPerSecond, double p95ResponseMs,
                                double cpuCores, double memoryMB, double ioPerSecond) {}
    public record ComparisonReport(boolean throughputPassed, boolean latencyPassed,
                                    boolean resourcePassed, double throughputRatio,
                                    double latencyRatio, double cpuEfficiency) {}
}
```

## SLA Monitoring Configuration

### Micrometer Timer Configuration

```java
@Configuration
public class SlaMetricsConfig {

    @Bean
    public MeterRegistryCustomizer<MeterRegistry> slaMetrics() {
        return registry -> {
            registry.config().commonTags(
                "application", "${APP_NAME}",
                "environment", "${ENV}",
                "sla_version", "1.0"
            );
        };
    }

    @Bean
    public TimedAspect timedAspect(MeterRegistry registry) {
        return new TimedAspect(registry);
    }
}

@Service
public class SlaMonitoredService {

    private final MeterRegistry meterRegistry;

    public SlaMonitoredService(MeterRegistry meterRegistry) {
        this.meterRegistry = meterRegistry;
    }

    @Timed(value = "cust_inquiry_latency", percentiles = {0.5, 0.95, 0.99})
    public CustomerResponse inquiry(String customerId) {
        Timer.Sample sample = Timer.start(meterRegistry);
        try {
            return doInquiry(customerId);
        } finally {
            sample.stop(Timer.builder("cust_inquiry_full")
                .publishPercentiles(0.5, 0.95, 0.99)
                .register(meterRegistry));
        }
    }

    private CustomerResponse doInquiry(String customerId) {
        // business logic
        return new CustomerResponse();
    }
}
```

### application.yml SLA Configuration

```yaml
management:
  metrics:
    tags:
      application: ${APP_NAME}
      environment: ${ENV}
    export:
      prometheus:
        enabled: true
        step: 30s
    distribution:
      percentiles-histogram:
        http.server.requests: true
        cust_inquiry_latency: true
      sla:
        P50: ${P50_TARGET}
        P95: ${P95_TARGET}
        P99: ${P99_TARGET}
      minimum-expected-value:
        http.server.requests: 1ms
      maximum-expected-value:
        http.server.requests: 5000ms
  endpoint:
    health:
      show-details: always
      group:
        sla:
          include: ["livenessState", "readinessState", "dbCheck"]
```

## Integration Notes

- Referenced by: quality-checklist.md checks 1-30 (performance validation), SKILL.md Phase 10h (Performance benchmarking), SKILL.md Stage 3 (Extended phases), production-patterns.md
- Last reviewed: 2026-05-04
