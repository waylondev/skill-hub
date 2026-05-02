# Production Migration Patterns

## Pattern 1: Strangler Fig (Safest for Large Systems)

Grow a new system around the old one — no big bang cutover.

```
Phase 1: API Gateway Layer
  Client → API Gateway → [COBOL Program B (existing)]
                          [Java Service A (new)]
                          [Java Service C (new)]

Phase 2: Gradual Traffic Shift
  - Route new features to Java services
  - Route existing features to COBOL via API wrapper
  - Test each endpoint independently
  - Roll back individual endpoints if needed

Phase 3: COBOL Read-Only
  - All writes go to Java
  - COBOL reads from new database (replicated)
  - Monitor for discrepancies

Phase 4: COBOL Decommission
  - All traffic to Java
  - COBOL kept as hot standby
  - After 30 days stable, decommission COBOL
```

## Pattern 2: Database Coexistence

Don't migrate DB and app simultaneously:

```
Phase 1: Java reads from legacy DB (VSAM via JDBC/APIs)
Phase 2: Java writes to both old and new (dual-write)
Phase 3: Verify data consistency (automated reconciliation)
Phase 4: Java reads from new DB
Phase 5: Decommission old DB
```

**Critical rules for dual-write:**
- Transactional outbox pattern for consistency
- Reconciliation script every 15 minutes
- If discrepancy, pause writes and alert
- Never delete legacy data until Phase 4 complete

## Pattern 3: API Gateway Wrapping

Maintain mainframe as system of record while building new frontend:

```
COBOL System (Mainframe)
    ↓ API Wrapper (HTTP/REST via CICS Web Services or MQ)
API Gateway (Kong, AWS API Gateway, or Spring Cloud Gateway)
    ↓
New Java Microservices (AWS/Azure/GCP)
    ↓
Frontend Applications (React, Mobile)
```

## Pattern 4: Canary Release

```
Phase 1: Deploy v2 to 5% traffic
  - Monitor error rates, response times, business metrics
  - Compare v1 vs v2 (Golden Test)
  - If stable 2 hours, proceed

Phase 2: Increase to 25%
  - Monitor edge cases
  - Check DB consistency
  - If stable 4 hours, proceed

Phase 3: Increase to 50%
  - Full load testing
  - Check resource utilization
  - If stable 8 hours, proceed

Phase 4: Increase to 100%
  - Keep v1 as hot standby 7 days
  - After 7 days stable, decommission v1
```

```yaml
# Argo Rollouts canary config
apiVersion: argoproj.io/v1alpha1
kind: Rollout
spec:
  strategy:
    canary:
      steps:
      - setWeight: 5
      - pause: {duration: 2h}
      - setWeight: 25
      - pause: {duration: 4h}
      - setWeight: 50
      - pause: {duration: 8h}
      - setWeight: 100
      - pause: {duration: 168h} # 7 days hot standby
```

## Pattern 5: Blue-Green Deployment

```
Phase 1: Deploy v2 (green) alongside v1 (blue)
  - Both running, only v1 receiving traffic
  - Run integration tests against v2

Phase 2: Switch traffic from v1 to v2
  - Update API Gateway/LB to v2
  - Instant cutover
  - Monitor 1 hour

Phase 3: Keep v1 (blue) as standby
  - Instant rollback if issues
  - After 24 hours stable, decommission v1
```

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
spec:
  strategy:
    blueGreen:
      activeService: card-service-active
      previewService: card-service-preview
      autoPromotionEnabled: false
      scaleDownDelaySeconds: 86400 # 24 hours
```

## Pattern 6: Feature Flags

```java
@Component
public class FeatureFlags {
    private final Map<String, Boolean> flags = new ConcurrentHashMap<>();

    @Value("${features.new-account-service:false}")
    public void setNewAccountService(boolean enabled) {
        flags.put("new-account-service", enabled);
    }

    public boolean isEnabled(String feature) {
        return flags.getOrDefault(feature, false);
    }
}

@Service
public class AccountService {
    private final FeatureFlags flags;
    private final AccountServiceV1 v1;
    private final AccountServiceV2 v2;

    public Account getAccount(Long id) {
        return flags.isEnabled("new-account-service")
            ? v2.getAccount(id) : v1.getAccount(id);
    }
}
```

## Rollback Plan

| Phase | Trigger | Rollback Action | Time |
|-------|---------|-----------------|------|
| Canary 5% | Error > 1% | Revert to v1 | < 1 min |
| Canary 25% | Metric deviation > 5% | Revert to v1 | < 2 min |
| Canary 50% | DB inconsistency | Revert + reconciliation | < 5 min |
| Blue-Green | Any critical issue | Switch LB back to blue | < 30 sec |

```yaml
# Automated rollback
apiVersion: argoproj.io/v1alpha1
kind: Rollout
spec:
  strategy:
    canary:
      analysis:
        templates:
        - templateName: error-rate-check
        - templateName: latency-check
        thresholds:
          failureThreshold: 3
          consecutiveSuccess: 5
```

## Data Migration Validation

```
Pre-Migration:
  - Backup all legacy data
  - Document schema mapping
  - Prepare rollback scripts

During Migration:
  - ETL with validation checkpoints
  - Compare record counts
  - Verify data integrity (checksums)

Post-Migration:
  - Automated reconciliation scripts
  - Sample manual verification (100+ records)
  - Monitor for data-related errors
```

## Cutover Checklist

- [ ] All integration tests pass (100%)
- [ ] Performance benchmarks meet targets
- [ ] DB migration completed and validated
- [ ] Rollback plan tested and documented
- [ ] Monitoring and alerting configured
- [ ] On-call team briefed
- [ ] Business stakeholders notified
- [ ] Traffic switching procedure rehearsed
- [ ] Golden Test baseline compared
- [ ] Risk mitigations in place

## Production Infrastructure Checklist

All migrated services MUST include:

- **Health Checks**: `/actuator/health` with liveness & readiness probes
- **Monitoring**: Micrometer + Prometheus + Grafana
- **Circuit Breaker**: Resilience4j with fallback methods
- **Rate Limiting**: Bucket4j or Redis-backed
- **Distributed Tracing**: Micrometer Tracing + Zipkin
- **Graceful Shutdown**: `server.shutdown: graceful` with 30s timeout
- **Connection Pooling**: HikariCP (min 5, max 20)
- **API Documentation**: SpringDoc OpenAPI 3.x
- **Structured Logging**: JSON format with correlation IDs
- **Secrets Management**: K8s Secrets or external vault (never in config files)
