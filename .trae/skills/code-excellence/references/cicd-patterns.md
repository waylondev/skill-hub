# CI/CD Pipeline Patterns — Principal Architect Reference

## Purpose

Production-grade continuous delivery patterns that every principal architect must embed into the engineering organization. Covers deployment strategies, pipeline architecture, artifact management, and release governance.

---

## CI-1: Deployment Strategy Selection

**Use when**: Designing how code reaches production. The deployment strategy directly determines risk exposure, rollback speed, and infrastructure cost.

### Deployment Strategy Matrix

| Strategy | Rollback Time | Infra Cost | User Impact | Best For |
|----------|--------------|------------|-------------|----------|
| **Rolling Update** | Per-pod (~30s) | Same as prod | Gradual (one pod at a time) | Stateless services |
| **Blue-Green** | Instant (switch LB) | 2× production | Zero (atomic switch) | Revenue-critical APIs |
| **Canary** | Instant (set %→0) | Prod + 1 canary | Minimal (X% users) | Risk-averse orgs |
| **A/B Testing** | Instant | Prod + 1 variant | Controlled | Feature experimentation |
| **Shadow/Dark** | Instant | Prod + shadow env | Zero (mirror only) | Validation before switch |

### ❌ Wrong — Direct-to-Prod Deploy

```yaml
# "We deploy straight to production. It's fine."
# No staging, no canary, no automated rollback.
# Deploy window: Friday 5pm. Rollback: manual, 15 minutes of downtime.

pipeline:
  build → unit-test → deploy-prod  # 3 steps, zero safety
```

### ✅ Expert Fix — Defense-in-Depth Deployment

```yaml
# Multi-stage deployment pipeline
pipeline:
  stages:
    - name: build
      steps:
        - compile
        - unit-test
        - static-analysis (C1-C15 compliance scan)
        - security-scan (SAST)
        - container-build
        - container-scan (Trivy/Snyk)
        - push-to-registry

    - name: deploy-staging
      steps:
        - deploy-to-staging
        - smoke-test (health, critical endpoints)
        - integration-test (Testcontainers)

    - name: canary
      steps:
        - deploy-canary (1 instance, 5% traffic)
        - monitor-5-minutes:
            metrics: [error_rate, latency_p99, cpu, memory]
            threshold: error_rate < 0.1% AND latency_p99 < 500ms
        - on-failure: auto-rollback  # INSTANT: set canary traffic to 0%

    - name: rolling-prod
      steps:
        - rolling-update (max 25% unavailable)
        - health-check-each-pod (readiness probe, 30s grace)
        - on-failure: pause-deploy, alert-oncall

    - name: post-deploy
      steps:
        - full-regression-suite
        - performance-baseline-compare
        - notify-release-channel

  rollback:
    strategy: automated
    trigger: error_rate > 0.5% OR latency_p99 > 1s (5-min window)
    action: kubectl rollout undo deployment/order-service
```

```yaml
# K8s Rolling Update — production-grade config
apiVersion: apps/v1
kind: Deployment
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 2            # at most 2 extra pods during deploy
      maxUnavailable: 1      # at most 1 pod down during deploy
  template:
    spec:
      terminationGracePeriodSeconds: 30
      containers:
        - readinessProbe:
            httpGet:
              path: /actuator/health/readiness
              port: 8080
            initialDelaySeconds: 10
            periodSeconds: 5
            failureThreshold: 3    # 3 failures = removed from LB
```

```java
// Deployment safety — pre-flight validation in CI
public class DeploymentGate {
    private static final double MAX_ERROR_RATE = 0.001;  // 0.1%
    private static final long MAX_P99_LATENCY_MS = 500;

    public boolean canProceed(MetricsSnapshot canaryMetrics) {
        return canaryMetrics.errorRate() <= MAX_ERROR_RATE
            && canaryMetrics.p99LatencyMs() <= MAX_P99_LATENCY_MS
            && canaryMetrics.cpuUtilization() < 0.85
            && canaryMetrics.memoryUtilization() < 0.85;
    }
}
```

**Expert Note**: The deployment strategy is not a DevOps decision — it's an architectural decision. Every strategy has trade-offs. Blue-Green costs 2× infrastructure but provides instant rollback — for payment services, this is mandatory. Rolling updates cost nothing extra but rollback takes 30s per pod — fine for 95% of services. The canary stage with an automated rollback gate is the cheap middle ground that every critical service should use.

---

## CI-2: Pipeline as Code Architecture

**Use when**: Building CI/CD from scratch or standardizing across teams. Pipeline design should be templated, not copy-pasted.

### ❌ Wrong — Copy-Paste CI per Service

```
50 microservices = 50 nearly-identical Jenkinsfiles/GitHub Actions.
When a security scan step changes → update 50 files. 47 updated, 3 missed.
```

### ✅ Expert Fix — Reusable Pipeline Templates

```yaml
# .github/workflows/_java-service-ci.yml (REUSABLE TEMPLATE)
name: Java Service CI
on:
  workflow_call:
    inputs:
      service-name:
        required: true
        type: string
      java-version:
        default: "21"
        type: string
      critical-service:
        default: false
        type: boolean

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      # UNIVERSAL gates — all services
      - name: Build
        run: ./gradlew build -x test

      - name: Static Analysis (C1-C15)
        run: ./gradlew checkstyle pmdMain spotbugsMain

      - name: Unit Tests
        run: ./gradlew test jacocoTestReport

      - name: Security Scan (SAST)
        run: ./gradlew dependencyCheckAnalyze

      - name: Container Build + Scan
        run: |
          docker build -t ${{ inputs.service-name }}:${{ github.sha }} .
          trivy image --severity HIGH,CRITICAL ${{ inputs.service-name }}:${{ github.sha }}

      # CRITICAL-only gates
      - name: Performance Baseline (Critical Services Only)
        if: ${{ inputs.critical-service }}
        run: ./gradlew jmh

      - name: Chaos Test (Critical Services Only)
        if: ${{ inputs.critical-service }}
        run: ./gradlew chaosTest

      - name: ADR Check (Critical Services Only)
        if: ${{ inputs.critical-service }}
        run: |
          if ! git diff --name-only HEAD~1 | grep -q "docs/adr/"; then
            echo "WARNING: Critical service changed without ADR update (C14)"
          fi
```

```yaml
# order-service/.github/workflows/ci.yml (CONSUMER — 5 lines!)
name: Order Service CI
on: [push, pull_request]
jobs:
  ci:
    uses: ./.github/workflows/_java-service-ci.yml
    with:
      service-name: order-service
      critical-service: true     # Revenue-critical = extra gates
```

**Pipeline Architecture Principles:**
| Principle | Implementation |
|-----------|---------------|
| **Template over copy** | Reusable workflows, shared CI config repo |
| **Fail early** | Fastest checks first: lint → unit → SAST → container scan |
| **Critical path extra gates** | Revenue/auth services: performance baseline + chaos test |
| **Artifact immutability** | Tag images with git SHA, never `:latest` in prod |
| **Pipeline as artifact** | CI config versioned in same repo, PR-reviewed |

**Expert Note**: Pipeline as Code is an architectural concern. A well-designed pipeline template has the same properties as well-designed code: DRY, single responsibility, testable. The template approach means adding a new security scan to ALL 50 services is a 1-line change in the template, not 50 PRs. `critical-service: true` is the architectural toggle — it doesn't change the pipeline shape, it adds depth.

---

## CI-3: Artifact Management & SBOM

**Use when**: Deploying to regulated environments (SOC2, HIPAA, PCI-DSS) or when supply chain security matters.

### ❌ Wrong — Unknown Dependencies, No SBOM

```dockerfile
FROM openjdk:latest    # "latest" = what broke last time? nobody knows.
COPY build/libs/*.jar app.jar  # no version pinning, no provenance
```

### ✅ Expert Fix — Pinned, Signed, SBOM-Attached

```dockerfile
# Pin EVERYTHING — reproducibility is security
FROM eclipse-temurin:21.0.4_7-jre-noble@sha256:a3b8c9d... # digest-pinned
LABEL org.opencontainers.image.version="${VERSION}"
LABEL org.opencontainers.image.revision="${GIT_SHA}"
LABEL org.opencontainers.image.created="${BUILD_DATE}"

COPY build/libs/order-service-${VERSION}.jar /app/app.jar

# Non-root user — least privilege (C6)
RUN addgroup --system app && adduser --system --group app
USER app:app

HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD wget -qO- http://localhost:8080/actuator/health || exit 1

EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
```

```yaml
# SBOM generation in CI
  - name: Generate SBOM (CycloneDX)
    uses: CycloneDX/gh-cyclonedx-generate@v1
    with:
      output-format: json
```

```json
// SBOM Consumer: dependency vulnerability check
{
  "bomFormat": "CycloneDX",
  "components": [
    {
      "name": "spring-boot-starter-web",
      "version": "3.2.5",
      "purl": "pkg:maven/org.springframework.boot/spring-boot-starter-web@3.2.5"
    }
  ]
}
```

**Artifact Trust Chain:**
```
[Source Code] → [CI builds + signs artifact] → [SBOM generated]
     → [Container signed with Cosign] → [Registry: only signed images]
     → [Deploy: verify signature before running] → [Runtime: read-only filesystem]
```

**Expert Note**: SBOM (Software Bill of Materials) is rapidly becoming a compliance requirement (US Executive Order 14028). But beyond compliance, SBOM enables automated vulnerability management — when log4shell hits, you query your SBOM registry for "does ANY service use log4j?" and get an answer in seconds, not days.

---

## CI-4: Feature Flag-Driven Release

**Use when**: Decoupling deployment from release at the CI/CD level. Merged code should never mean "shipped to all users."

### ❌ Wrong — Merge = Release to All Users

```yaml
# Every merge to main → deploys to prod → visible to 100% of users
# No kill switch. No gradual rollout. No A/B test capability.

on:
  push:
    branches: [main]
jobs:
  deploy-prod: # single stage, full blast
```

### ✅ Expert Fix — Dark Deployment + Flag-Driven Release

```yaml
# Stage 1: CI/CD deploys code DARK (feature flag = OFF)
# Stage 2: Product/Engineering enables flag to X% users
# Stage 3: Monitor → ramp to 100% → remove flag (cleanup)

deploy-and-release:
  needs: [build, test, security-scan]
  steps:
    # DEPLOY dark — code is running but unreachable (flag OFF)
    - name: Deploy to Production
      run: kubectl apply -f k8s/

    # Smoke test ensures service HEALTHY — feature still OFF
    - name: Smoke Test
      run: curl -f http://order-service/actuator/health

    # RELEASE: toggle feature flag (NOT a redeploy)
    # This step is manual or scheduled — separates deploy from release
    # Product manager clicks "Enable BNPL for 5% users" in LaunchDarkly
```

```java
// Feature flag configuration — LaunchedDarkly / Unleash / custom
@FeatureToggle(
    feature = "bnpl-checkout",
    rolloutPercentage = 5,
    targetGroups = {"beta-testers"},
    killSwitch = true,
    owner = "payments-team",
    expiresAt = "2026-09-01"  // cleanup reminder
)
public class BnplCheckoutToggle implements FeatureToggleSupplier {
    @Override
    public boolean isEnabled(UserContext ctx) {
        // Falls back to Kill Switch if LaunchDarkly unreachable
        return featureFlagService.isEnabled("bnpl-checkout", ctx);
    }
}
```

**Release vs Deploy Separation:**
```
Deploy:  Code is RUNNING in production (every merge)
Release: Code is VISIBLE to users (controlled, gradual)
Rollback: Turn flag OFF (INSTANT) — no redeploy needed

Feature Flag Lifecycle:
  [Flag Created] → [5% Canary, 1 day] → [50%, 2 days]
    → [100%, 1 week] → [Flag Removed from Code] — sprint+2 cleanup
```

**Expert Note**: The deploy ≠ release separation is the single most powerful concept in modern CI/CD. It means you can deploy 10 times a day with near-zero risk — if any feature causes issues, the kill switch disables it instantly without a rollback. The cleanup commitment (flag removed within 2 sprints of 100% rollout) prevents flag accumulation, which is the #1 technical debt in flag-driven systems.

---

## CI-5: Database Migration in CI/CD

**Use when**: Database schema changes deploy alongside application code. The order of operations is critical for zero-downtime.

### ❌ Wrong — Migration Before or After Code (Either = Crash Window)

```yaml
# Simultaneous DB migration + code deploy
# Migration runs, drops old column → App still queries old column → CRASH

pipeline:
  - db-migrate     # DROP COLUMN old_total
  - deploy-app     # App: SELECT new_total → column exists, but...
```
**Problem**: Between migration and deploy, there's a window where DB has changed but code hasn't (or vice versa).

### ✅ Expert Fix — Expand-Contract in CI Pipeline

```yaml
# RELEASE-1 (Expand): Add, don't remove. Safe at any timing.
release-v1:
  db-migration:
    sql: ALTER TABLE orders ADD COLUMN total_amount NUMERIC;  # ADD only
  app-deploy:
    code: dual-write to both 'total' AND 'total_amount'

# RELEASE-2 (Wait): Let RELEASE-1 run for 1 week. All rows populated.
# No code changes. Just wait.

# RELEASE-3 (Contract): Remove old column. ALL code reads new column.
release-v3:
  app-deploy:
    code: read ONLY from 'total_amount'
  db-migration:
    sql: ALTER TABLE orders DROP COLUMN total;  # SAFE: nothing reads it
```

```yaml
# CI enforcement — reject destructive migrations in pipeline
migration-validation:
  rules:
    - forbid: "DROP COLUMN|DROP TABLE|RENAME COLUMN"
      message: "Destructive changes require expand-contract pattern (RF-4)."
      except: "preceded by 2+ releases of dual-write + verification period"
```

**Expert Note**: The CI/CD pipeline should REJECT destructive database migrations. This is not a DBA preference — it's an architectural constraint. If a migration contains `DROP COLUMN`, the pipeline should ask: "Has this column been unused for at least 2 releases? Prove it." The `critical-service: true` toggle in CI-2 should also enforce this check.

---

## Quick CI/CD Pipeline Checklist

- [ ] Deployment strategy chosen per service (rolling/canary/blue-green)?
- [ ] Canary stage with automated metrics-based rollback gate?
- [ ] Pipeline template approach — DRY, shared across teams?
- [ ] Container images tagged with git SHA, never `:latest` in prod?
- [ ] SBOM generated and attached to every release?
- [ ] Non-root container user (C6 — least privilege)?
- [ ] Feature flag lifecycle: deploy dark → release gradual → flag cleanup?
- [ ] Database migrations: expand-contract enforced in CI (no destructive single-step)?
- [ ] Rollback strategy documented and tested (not theoretical)?
- [ ] Pipeline execution time < 15 min (fast feedback loop)?
