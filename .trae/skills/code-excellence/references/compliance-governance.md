# Compliance & Governance — Architect-Level Reference

## Purpose

Production-grade compliance and governance patterns that every architect must embed
into system design, CI/CD pipelines, and operational procedures. Covers data
sovereignty, code quality gates, API lifecycle governance, audit requirements,
access control, and third-party risk.

When you are designing for regulated industries (finance, healthcare, public sector)
or any system handling personal data, consult this file before writing code.

---

## 1. GDPR / Data Sovereignty Compliance Checklist

### Data Minimization

Collect only what is strictly necessary. Every field must have a documented purpose.

```yaml
# data-fields-manifest.yaml — every PII field must be declared
fields:
  - name: email
    purpose: account_authentication
    legal_basis: contract
    retention_days: 365
    encryption: at_rest
    categories: [confidential]

  - name: phone_number
    purpose: two_factor_authentication
    legal_basis: contract
    retention_days: 365
    encryption: at_rest
    categories: [confidential]

  - name: date_of_birth
    purpose: age_verification
    legal_basis: legal_obligation
    retention_days: 90
    encryption: at_rest
    categories: [restricted]
    # If purpose expires → automatic purge job must delete
```

**Rule**: If a field has no `purpose` or `legal_basis`, it cannot be collected.

### Purpose Limitation

Data collected for one purpose must not be used for another without renewed consent.

```java
@Service
public class MarketingService {
    // ❌ WRONG: using account email for marketing without explicit consent
    public void sendPromotions(User user) {
        emailService.send(user.email(), promotionalContent);
    }

    // ✅ CORRECT: check marketing_consent flag separately
    public void sendPromotions(User user) {
        if (!user.marketingConsent()) {
            log.info("Skipping marketing for user {} — no consent", user.id());
            return;
        }
        emailService.send(user.email(), promotionalContent);
        auditService.record(MARKETING_EMAIL_SENT, user.id());
    }
}
```

### Right to Erasure (Right to be Forgotten)

```java
@Service
public class DataErasureService {
    @Transactional
    public void eraseUserData(Long userId) {
        // 1. Verify identity and eligibility
        var user = userRepo.findById(userId).orElseThrow();
        if (user.hasActiveOrders()) {
            throw new ErasureBlockedException("Active orders prevent erasure");
        }

        // 2. Anonymize or delete — NEVER leave orphaned PII
        orderRepo.anonymizeUserReferences(userId);   // replace with hash
        auditRepo.purgeUserRecords(userId);          // delete audit where legal
        backupRepo.schedulePurge(userId, retentionPolicy.legalHoldExpiry());

        // 3. Propagate to downstream systems
        eventPublisher.publish(new UserErasureEvent(userId, Instant.now()));

        // 4. Record the erasure itself (meta-audit)
        auditService.record(USER_DATA_ERASED, userId, Map.of("trigger", "user_request"));
    }
}
```

**Erasure rules**:
- **Anonymize** where retention is required for legal/accounting reasons (replace user ID with one-way hash)
- **Delete** where no legal hold applies
- **Schedule purge** from backups after legal hold expires
- **Propagate event** to all microservices that hold copies of the data

### Cross-Border Transfer

| Transfer Scenario | Mechanism | Verification |
|-------------------|-----------|--------------|
| EU → EU/EEA | Free | None |
| EU → Adequate Country (e.g., UK, Japan, S. Korea) | Free | Check adequacy decision date |
| EU → US (cloud services) | Standard Contractual Clauses (SCCs) + Technical measures | Encryption in transit + at rest. Data residency controls. |
| EU → No adequacy, no SCCs | **Prohibited** | Block at infrastructure level |

```yaml
# infrastructure/policies/data-residency.rego
package data_residency

deny[msg] {
    input.storage_region != input.allowed_regions[_]
    msg := sprintf("Data residency violation: storage %s not in allowed %v", [input.storage_region, input.allowed_regions])
}

deny[msg] {
    input.replication_regions[_] != input.allowed_regions[_]
    msg := sprintf("Replication region not in allowed list: %v", [input.replication_regions])
}
```

---

## 2. Code Governance Rules

### SonarQube Quality Gates

```yaml
# sonar-project.properties — production gate
sonar.qualitygate.wait=true
sonar.coverage.exclusions=**/*Test.java,**/generated/**,**/config/**

# Quality Gate Conditions (production)
# - Coverage >= 80%
# - Duplicated Lines <= 3%
# - Maintainability Rating == A
# - Reliability Rating == A
# - Security Rating == A
# - Critical Issues == 0
# - Blocker Issues == 0
```

### Code Coverage Thresholds

| Layer | Minimum Coverage | Enforced By |
|-------|-----------------|-------------|
| Domain / Business Logic | 90% | JaCoCo + CI gate |
| Service Layer | 80% | JaCoCo + CI gate |
| Controller / API Layer | 70% | JaCoCo + CI gate |
| Infrastructure / Config | 0% (excluded) | Explicit exclusion |
| Integration Tests | 60% (line) | Separate CI stage |

```xml
<!-- pom.xml — JaCoCo thresholds -->
<plugin>
  <groupId>org.jacoco</groupId>
  <artifactId>jacoco-maven-plugin</artifactId>
  <configuration>
    <rules>
      <rule>
        <element>BUNDLE</element>
        <limits>
          <limit>
            <counter>LINE</counter>
            <value>COVEREDRATIO</value>
            <minimum>0.80</minimum>
          </limit>
          <limit>
            <counter>BRANCH</counter>
            <value>COVEREDRATIO</value>
            <minimum>0.70</minimum>
          </limit>
        </limits>
      </rule>
    </rules>
  </configuration>
</plugin>
```

### Cyclomatic Complexity Limits

```java
// Enforced by Checkstyle / PMD / ArchUnit
// Maximum cyclomatic complexity per method: 10
// Maximum per class: 50

// ❌ Complexity = 12 — violates gate
public PaymentResult processPayment(PaymentRequest req) {
    if (req.type() == CARD) { ... }
    else if (req.type() == BANK_TRANSFER) { ... }
    else if (req.type() == WALLET) { ... }
    else if (req.type() == CRYPTO) { ... }
    else if (req.type() == BNPL) { ... }
    // Each branch adds complexity. Extract strategy pattern.
}

// ✅ Complexity = 2 — delegate to strategies
public PaymentResult processPayment(PaymentRequest req) {
    var processor = processorRegistry.get(req.type());
    return processor.process(req);
}
```

### Duplication Limits

| Metric | Threshold | Action if Exceeded |
|--------|-----------|-------------------|
| Duplicated Lines | <= 3% | Block merge |
| Duplicated Blocks | 0 blocks >= 6 lines | Block merge |
| Copy-paste in tests | 0 blocks >= 10 lines | Warn, require helper method |

---

## 3. API Governance

### Breaking Change Detection with OpenAPI Diff

```yaml
# .github/workflows/api-breaking-change.yml
name: API Breaking Change Detection
on:
  pull_request:
    paths: ['openapi/*.yaml']

jobs:
  breaking-change:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Download baseline OpenAPI
        run: curl -o baseline.yaml https://api.example.com/openapi.yaml
      - name: Run OpenAPI Diff
        uses: oasdiff/oasdiff-action/breaking@main
        with:
          base: baseline.yaml
          revision: openapi/api.yaml
          fail-on-breaking: true
```

**Breaking changes** (must trigger major version bump):
- Removing an endpoint
- Removing a required request field
- Adding a required request field
- Changing response field type
- Removing a response field
- Changing enum values (removing)
- Changing authentication requirements

**Non-breaking changes** (minor or patch):
- Adding optional request fields
- Adding response fields
- Adding endpoints
- Relaxing validation

### Versioning Strategy

```
URL Path Versioning (mandatory for public APIs)
  /v1/orders
  /v2/orders

Rules:
- Major version in URL path
- Minor/patch in response header: X-API-Version: 2.1.3
- Sunset header on deprecated versions: Sunset: Sat, 31 Dec 2026 23:59:59 GMT
- Max 2 major versions supported simultaneously
- Deprecation notice minimum 12 months before sunset
```

```yaml
# openapi/api.yaml
openapi: 3.1.0
info:
  title: Order API
  version: 2.1.3
  x-deprecation-policy: https://docs.example.com/api/deprecation

paths:
  /v2/orders:
    get:
      operationId: listOrders
      responses:
        200:
          description: OK
          headers:
            Sunset:
              schema:
                type: string
                example: "Sat, 31 Dec 2026 23:59:59 GMT"
            Deprecation:
              schema:
                type: boolean
                example: false
```

### Deprecation Policy

```java
// Deprecation must be explicit in code, docs, and headers
@RestController
@RequestMapping("/v1/orders")
public class OrderControllerV1 {

    @GetMapping("/{id}")
    @Deprecated(since = "2025-06-01", forRemoval = true)
    public ResponseEntity<OrderV1> getOrder(@PathVariable Long id, HttpServletResponse response) {
        response.setHeader("Deprecation", "true");
        response.setHeader("Sunset", "Sat, 31 Dec 2026 23:59:59 GMT");
        response.setHeader("Link", "</v2/orders/{id}>; rel=successor-version");
        return ResponseEntity.ok(orderServiceV1.get(id));
    }
}
```

### API Catalog

```yaml
# Every service must register in the API catalog
service:
  name: order-service
  owner_team: fulfillment-platform
  openapi_url: https://order-service.internal/openapi.yaml
  lifecycle: production   # production | beta | deprecated | sunset
  dependencies:
    - payment-service
    - inventory-service
  consumers:
    - web-frontend
    - mobile-app
  sla:
    availability: 99.99
    latency_p99: 200ms
  data_classification: confidential
```

---

## 4. Audit and Compliance Logging Requirements

### Immutable Audit Trails

```java
@Entity
@Table(name = "audit_log")
public class AuditRecord {
    @Id
    private UUID id;

    private String traceId;
    private String actorId;
    private String actorRoles;
    private String action;        // CREATE, READ, UPDATE, DELETE, EXPORT
    private String resourceType;
    private String resourceId;

    @Column(columnDefinition = "TEXT")
    private String beforeSnapshot;   // JSON snapshot before change

    @Column(columnDefinition = "TEXT")
    private String afterSnapshot;    // JSON snapshot after change

    private String clientIp;
    private Instant timestamp;

    // Cryptographic integrity: HMAC of all fields
    private String integrityHash;

    @PrePersist
    public void computeHash() {
        this.integrityHash = HmacSha256.sign(concatFields(), auditKey);
    }
}
```

**Database-level immutability**:

```sql
-- PostgreSQL: revoke all DML except INSERT on audit table
REVOKE UPDATE, DELETE, TRUNCATE ON audit_log FROM app_user;
GRANT INSERT ON audit_log TO app_user;

-- Row-level security: app_user can only INSERT, never SELECT/UPDATE/DELETE
ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;
CREATE POLICY audit_insert_only ON audit_log
    FOR ALL TO app_user
    USING (false)   -- cannot read
    WITH CHECK (true);  -- can insert
```

### Tamper-Proof Storage

| Layer | Mechanism | Implementation |
|-------|-----------|----------------|
| Application | HMAC per record | HMAC-SHA256 of all fields with KMS-held key |
| Database | Append-only + RLS | No UPDATE/DELETE grants |
| Infrastructure | WORM storage | S3 Object Lock (Compliance mode), Azure Immutable Blob |
| Log forwarding | Signed log shipping | TLS + mTLS to SIEM. Log signing with private key. |

### Retention Policies

```yaml
# retention-policy.yaml
audit_logs:
  production:
    hot_storage: 90 days      # queryable in database
    warm_storage: 1 year      # object storage, compressed
    cold_storage: 7 years     # glacier / tape — legal hold
    deletion: prohibited      # never delete, only move to cold

  non_production:
    hot_storage: 30 days
    warm_storage: 90 days
    deletion: allowed_after_1_year

security_events:
  retention: 7 years
  siem_forwarding: real_time

application_logs:
  retention: 30 days
  pii_redaction: required
```

### SIEM Integration

```java
@Component
public class SiemForwarder {
    private final WebClient siemClient;

    public void forward(AuditEvent event) {
        var siemPayload = Map.of(
            "event_type", event.action(),
            "severity", mapSeverity(event.action()),
            "actor", event.actorId(),
            "resource", event.resourceType() + "/" + event.resourceId(),
            "timestamp", event.timestamp().toString(),
            "source", "order-service",
            "environment", System.getenv("ENV"),
            "integrity_hash", event.integrityHash()
        );

        siemClient.post()
            .uri("/api/v1/events")
            .bodyValue(siemPayload)
            .retrieve()
            .toBodilessEntity()
            .retryWhen(Retry.backoff(3, Duration.ofSeconds(1)))
            .subscribe();
    }
}
```

---

## 5. Access Control Governance

### RBAC / ABAC Review Cycles

```yaml
# access-review-policy.yaml
rbac_reviews:
  frequency: quarterly
  approver: security_team + data_owner
  actions:
    - remove_orphaned_roles
    - revoke_dormant_accounts_after_90_days
    - revalidate_privileged_access
    - document_exceptions

abac_policies:
  review_frequency: semi_annually
  test_coverage: 100% of policy rules must have unit tests
  change_approval: ciso + legal
```

### Privileged Access Management (PAM)

```java
@Service
public class PrivilegedAccessService {
    // Break-glass access: time-bound, audited, requires dual approval
    public ElevatedSession requestElevatedAccess(User requester, Privilege privilege) {
        // 1. Require dual approval for production privileged access
        var approvals = approvalService.getActiveApprovals(requester.id(), privilege);
        if (approvals.size() < 2) {
            throw new InsufficientApprovalsException("Requires 2 approvals, found " + approvals.size());
        }

        // 2. Time-bound: max 4 hours
        var session = ElevatedSession.builder()
            .requester(requester.id())
            .privilege(privilege)
            .grantedBy(approvals.stream().map(Approval::approverId).toList())
            .expiresAt(Instant.now().plus(Duration.ofHours(4)))
            .build();

        // 3. Immediate audit + real-time alert
        auditService.record(PRIVILEGE_ELEVATED, requester.id(), Map.of(
            "privilege", privilege.name(),
            "approvers", session.grantedBy(),
            "expires", session.expiresAt()
        ));
        alertService.sendToSecurityTeam("Privileged access granted", session);

        return session;
    }
}
```

### Least Privilege Enforcement

```yaml
# Terraform: IAM policy with least privilege
resource "aws_iam_policy" "order_service" {
  name = "order-service-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query"
        ]
        Resource = aws_dynamodb_table.orders.arn
        Condition = {
          StringEquals = {
            "dynamodb:LeadingKeys" = ["order#*"]
          }
        }
      },
      {
        Effect   = "Deny"
        Action   = "dynamodb:*"
        Resource = aws_dynamodb_table.users.arn  # explicit deny
      }
    ]
  })
}
```

---

## 6. Data Classification and Handling

### Classification Levels

| Level | Definition | Encryption at Rest | Encryption in Transit | Access Control | Example |
|-------|-----------|-------------------|----------------------|----------------|---------|
| **Public** | No harm if disclosed | None | TLS | None | Product catalog, pricing |
| **Internal** | Business discomfort if disclosed | None | TLS | Authenticated | Business metrics, roadmaps |
| **Confidential** | Significant harm if disclosed | AES-256 (DB-level) | TLS 1.3 | RBAC + need-to-know | Customer email, order history |
| **Restricted** | Severe harm / legal liability | AES-256 + KMS + application-level | TLS 1.3 + mTLS | ABAC + MFA + approval | SSN, credit card, health records |

### Handling Rules by Classification

```java
public enum DataClassification {
    PUBLIC, INTERNAL, CONFIDENTIAL, RESTRICTED;

    public EncryptionRequirement encryption() {
        return switch (this) {
            case PUBLIC, INTERNAL -> EncryptionRequirement.NONE;
            case CONFIDENTIAL -> EncryptionRequirement.AT_REST;
            case RESTRICTED -> EncryptionRequirement.AT_REST_AND_APPLICATION;
        };
    }

    public AccessRequirement access() {
        return switch (this) {
            case PUBLIC -> AccessRequirement.NONE;
            case INTERNAL -> AccessRequirement.AUTHENTICATED;
            case CONFIDENTIAL -> AccessRequirement.RBAC;
            case RESTRICTED -> AccessRequirement.ABAC_MFA;
        };
    }
}

// Enforced at API boundary
public record ApiResponse<T>(
    T data,
    DataClassification classification
) {
    public ApiResponse {
        if (classification == DataClassification.RESTRICTED && !Context.hasMfa()) {
            throw new MfaRequiredException("Restricted data requires MFA");
        }
    }
}
```

### Encryption Implementation

```java
// Application-level encryption for RESTRICTED fields
@Component
public class FieldEncryption {
    private final KmsClient kms;

    public String encrypt(String plaintext, DataClassification classification) {
        if (classification != DataClassification.RESTRICTED) {
            return plaintext; // only RESTRICTED gets app-level encryption
        }
        var dataKey = kms.generateDataKey(keyId);
        var encrypted = AesGcm.encrypt(plaintext.getBytes(UTF_8), dataKey.plaintext());
        return Base64.getEncoder().encodeToString(encrypted) + ":" + dataKey.encryptedKey();
    }

    public String decrypt(String ciphertext, DataClassification classification) {
        if (classification != DataClassification.RESTRICTED) {
            return ciphertext;
        }
        var parts = ciphertext.split(":");
        var encryptedData = Base64.getDecoder().decode(parts[0]);
        var encryptedKey = Base64.getDecoder().decode(parts[1]);
        var plaintextKey = kms.decrypt(encryptedKey);
        return new String(AesGcm.decrypt(encryptedData, plaintextKey), UTF_8);
    }
}
```

---

## 7. Compliance Automation

### Policy-as-Code with OPA / Rego

```rego
# policies/compliance/data-residency.rego
package compliance.data_residency

import future.keywords.if
import future.keywords.in

allowed_regions := {"eu-west-1", "eu-central-1", "eu-north-1"}

deny[msg] {
    input.resource_type == "s3_bucket"
    input.region != allowed_regions[_]
    msg := sprintf("S3 bucket %s in non-compliant region %s", [input.name, input.region])
}

deny[msg] {
    input.resource_type == "rds_instance"
    not input.encryption_at_rest
    msg := sprintf("RDS instance %s must have encryption at rest", [input.name])
}

deny[msg] {
    input.resource_type == "iam_policy"
    input.statement.effect == "Allow"
    input.statement.action == "*"
    msg := sprintf("IAM policy %s has wildcard action — violates least privilege", [input.name])
}
```

```yaml
# .github/workflows/compliance-check.yml
name: Compliance Policy Check
on: [pull_request]

jobs:
  opa:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run OPA tests
        run: |
          opa test policies/ --verbose
      - name: Evaluate Terraform plan against policies
        run: |
          terraform plan -out=tfplan
          terraform show -json tfplan > plan.json
          opa eval --data policies/compliance --input plan.json "data.compliance.deny"
```

### Automated Compliance Checks in CI/CD

```yaml
# .github/workflows/main.yml
stages:
  - name: security-scan
    steps:
      - trivy filesystem --severity HIGH,CRITICAL .
      - snyk test --severity-threshold=high
      - sonar-scanner -Dsonar.qualitygate.wait=true

  - name: compliance-check
    steps:
      - opa test policies/
      - checkov -d terraform/
      - terraform-compliance -f terraform/ -p compliance-features/

  - name: sbom-generation
    steps:
      - syft packages dir:. -o cyclonedx-json > sbom.json
      - grype sbom:sbom.json --fail-on high

  - name: deploy
    needs: [security-scan, compliance-check, sbom-generation]
    if: github.ref == 'refs/heads/main'
```

### Compliance Dashboard

```yaml
# Metrics exposed for compliance dashboard
compliance_metrics:
  - name: policy_violations_open
    type: gauge
    labels: [policy_name, severity, team]

  - name: audit_log_integrity_check
    type: gauge
    value: 1 if last_verification_passed else 0

  - name: data_classification_coverage
    type: gauge
    labels: [classification]
    # percentage of resources tagged with classification label

  - name: access_review_overdue
    type: gauge
    labels: [team, access_type]

  - name: third_party_risk_score
    type: gauge
    labels: [vendor_name]
    value: 0-100 based on assessment
```

---

## 8. Incident Response Governance

### Breach Notification Timelines

| Jurisdiction | Notification To | Timeline | Trigger |
|--------------|-----------------|----------|---------|
| GDPR (EU) | Supervisory Authority | 72 hours | Likely result in risk to rights/freedoms |
| GDPR (EU) | Affected Individuals | Without undue delay | High risk to rights/freedoms |
| US State Laws (e.g., CCPA) | Attorney General + Individuals | 72 hours — variable by state | Unauthorized access to personal info |
| HIPAA (US Health) | HHS + Individuals + Media (>500) | 60 days (HHS), 60 days (individuals) | PHI breach |
| PCI-DSS | Acquirer + Card Brands | Immediately | CHD compromise |

```java
@Service
public class BreachNotificationService {
    public void assessAndNotify(SecurityIncident incident) {
        var assessment = privacyTeam.assessBreach(incident);

        if (assessment.isReportable()) {
            // Parallel notification tracks
            var notifications = List.of(
                notifySupervisoryAuthority(assessment),   // 72h SLA
                notifyAffectedIndividuals(assessment),    // high risk
                notifyLegalTeam(assessment),
                notifyInsurance(assessment)
            );

            // Track SLA compliance
            notifications.forEach(n -> slaTracker.start(n.type(), n.deadline()));
        }

        // Always: preserve forensic evidence
        forensicService.createLegalHold(incident);
    }
}
```

### Forensic Preservation

```yaml
# incident-response/forensic-preservation.yml
forensic_evidence:
  sources:
    - application_logs
    - audit_logs
    - database_transaction_logs
    - network_flow_logs
    - container_runtime_logs
    - iam_access_logs

  preservation:
    immediate_snapshot: true
    write_once_storage: true
    chain_of_custody: required
    retention: 7_years_post_resolution

  handling:
    encryption: aes_256_gcm
    access: incident_response_team_only
    logging: all_access_logged_to_separate_audit_trail
```

### Root Cause Analysis Requirements

```markdown
# RCA Template — Mandatory for SEV-1 and SEV-2 incidents

## Incident Summary
- ID: INC-2026-0042
- Severity: SEV-1
- Detection: Automated alert (SIEM)
- Time to Detect: 4 minutes
- Time to Mitigate: 23 minutes
- Time to Resolve: 4 hours

## Timeline (minute-by-minute)
- T+0: Anomaly detected in authentication logs
- T+4: PagerDuty alert triggered
- T+8: Incident commander assigned
- T+15: Affected service isolated
- T+23: Attack vector blocked
- T+240: Full service restored

## Root Cause
- What: Missing rate limiting on password reset endpoint
- Why: New endpoint deployed without security review
- Why: Security review checklist not enforced for "internal" endpoints
- Why: Internal endpoint misclassified — exposed to internet via gateway

## 5 Whys
1. Why did the breach occur? → Attacker brute-forced password reset
2. Why was brute-forcing possible? → No rate limiting
3. Why was there no rate limiting? → Endpoint skipped security review
4. Why was review skipped? → "Internal" classification bypassed checklist
5. Why was classification wrong? → Gateway config not in IaC, manually edited

## Corrective Actions
| Action | Owner | Due Date | Status |
|--------|-------|----------|--------|
| Add rate limiting to all auth endpoints | Platform | 2026-05-15 | Open |
| Gateway config in Terraform only | SRE | 2026-05-10 | Open |
| Security review mandatory for ALL endpoints | Security | 2026-05-08 | Open |
| Add auth endpoint to automated penetration tests | QA | 2026-05-20 | Open |

## Lessons Learned
- "Internal" is not a security boundary. Network location ≠ trust.
- Any endpoint reachable from the gateway needs full security treatment.
- Manual infrastructure changes bypass all governance.
```

---

## 9. Third-Party Risk Management

### Vendor Assessment

```yaml
# vendor-assessment-template.yaml
vendor:
  name: "Acme Cloud Storage"
  criticality: high   # high | medium | low
  data_access: [confidential, restricted]
  assessment:
    security_certifications: [SOC2_Type2, ISO27001]
    penetration_test_date: 2026-01-15
    penetration_test_next_due: 2026-07-15
    data_residency_guarantee: true
    encryption_at_rest: AES-256
    encryption_in_transit: TLS_1_3
    access_logging: true
    audit_rights: true
    breach_notification_sla: 24_hours
    termination_data_return: 30_days
    sub_processors_disclosed: true

  risk_score:
    security: 85/100
    compliance: 90/100
    operational: 75/100
    overall: 83/100

  approval:
    security_team: approved
    legal: approved
    procurement: approved
    ciso: approved
    review_date: 2026-11-01
```

### SBOM Requirements

```yaml
# .github/workflows/sbom.yml
name: SBOM Generation and Attestation
on:
  push:
    branches: [main]
  release:
    types: [published]

jobs:
  sbom:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Generate SBOM
        uses: anchore/sbom-action@v0
        with:
          format: cyclonedx-json
          output-file: sbom.cyclonedx.json
      - name: Sign SBOM
        uses: sigstore/cosign-installer@v3
      - run: cosign sign-blob --yes sbom.cyclonedx.json --output-signature sbom.cyclonedx.json.sig
      - name: Attach to release
        uses: softprops/action-gh-release@v1
        with:
          files: |
            sbom.cyclonedx.json
            sbom.cyclonedx.json.sig
```

**SBOM consumption rules**:
- Every artifact must have an SBOM at build time
- SBOM must be signed (cosign / Notary)
- SBOM must be stored for the lifetime of the artifact + 7 years
- Vulnerability scan against SBOM before deployment (Grype, Snyk)

### Security Questionnaires

```yaml
# security-questionnaire-template.yaml
third_party_security_questionnaire:
  sections:
    - name: data_handling
      questions:
        - id: DH-01
          text: "Do you process personal data on our behalf?"
          required: true
          acceptable_answers: [yes_with_dpa, no]
          unacceptable_answers: [yes_without_dpa]

        - id: DH-02
          text: "What is your data retention period after contract termination?"
          required: true
          validation: "<= 90 days"

    - name: access_control
      questions:
        - id: AC-01
          text: "Do you enforce MFA for all administrative access?"
          required: true
          acceptable_answers: [yes]

        - id: AC-02
          text: "Do you perform quarterly access reviews?"
          required: true
          acceptable_answers: [yes]

    - name: incident_response
      questions:
        - id: IR-01
          text: "What is your breach notification SLA?"
          required: true
          validation: "<= 24 hours"

        - id: IR-02
          text: "Do you conduct annual penetration tests by a third party?"
          required: true
          acceptable_answers: [yes]

  scoring:
    auto_fail_conditions:
      - any_required_question_unanswered
      - any_unacceptable_answer
      - overall_score < 70
```

---

## 10. Documentation Governance

### ADR Requirements

Every architectural decision that is not the obvious default must be documented.

```markdown
# ADR-042: Compliance Logging Strategy

## Status
Accepted (2026-04-10)

## Context
We need audit logging that satisfies SOC2 Type II, GDPR Article 30, and PCI-DSS 10.2.
Requirements:
- Immutable audit trail
- Tamper detection
- 7-year retention
- Real-time SIEM forwarding
- Survive transaction rollback

Options considered:
1. Application logs to ELK — not immutable, can be altered
2. Database trigger audit table — survives rollback, but DB admin can modify
3. Separate append-only audit database + HMAC + WORM storage — meets all requirements

## Decision
Use option 3: dedicated audit database with separate credentials, HMAC per record,
WORM object storage backup, and real-time SIEM forwarding.

## Consequences
**Positive**: Meets all compliance requirements. Independent security boundary.
**Negative**: Operational complexity (second database). Latency overhead (~5ms per audit event).
**Mitigation**: Async audit publishing via outbox pattern.
```

**ADR rules**:
- One ADR per significant decision
- Status: Proposed → Accepted → Deprecated → Superseded
- Superseded ADRs must link to their replacement
- ADRs are immutable after acceptance — amendments get new ADR numbers

### Runbook Standards

```markdown
# Runbook: Order Service Database Failover

## Metadata
- Service: order-service
- Owner: fulfillment-platform
- Severity: SEV-1 if unplanned
- Last Reviewed: 2026-04-01
- Review Cycle: quarterly

## Symptoms
- Alert: `order_db_replication_lag > 30s`
- Alert: `order_db_connection_pool_exhausted`
- Customer reports: orders not persisting

## Prerequisites
- Access: production-read role + break-glass approval
- Tools: kubectl, psql, PagerDuty

## Procedure
1. Verify primary health: `kubectl exec -it order-db-0 -- pg_isready`
2. Check replication lag: `SELECT EXTRACT(EPOCH FROM (now() - pg_last_xact_replay_timestamp())) AS lag;`
3. If lag > 60s and rising → initiate failover
4. Promote replica: `kubectl exec -it order-db-1 -- pg_ctl promote`
5. Update service endpoints: `kubectl patch service order-db --patch '{"spec":{"selector":{"role":"primary"}}}'`
6. Verify application recovery: check `/health` endpoint returns 200
7. Notify: post in #incidents, update status page

## Rollback
- If failover causes data inconsistency → restore from latest backup + WAL replay
- Contact: DBA on-call (auto-page via PagerDuty)

## Post-Incident
- Required: RCA within 48 hours
- Required: Update runbook if procedure changed
```

### API Documentation Standards

```yaml
# openapi/documentation-standards.yaml
api_documentation:
  required_sections:
    - summary: "One-line description of what this endpoint does"
    - description: "Detailed behavior, side effects, idempotency guarantees"
    - operationId: "Unique identifier for code generation and tracing"
    - tags: ["Logical group for documentation UI"]
    - parameters:
        - name: "Parameter name"
          description: "What this parameter controls"
          example: "Concrete example value"
          required: true/false
    - requestBody:
        description: "What the request represents"
        example: "Full valid request body"
    - responses:
        "200":
          description: "What success means in business terms"
          example: "Full valid response body"
        "400":
          description: "What validation errors look like"
          example: '{"error": "INVALID_CURRENCY", "message": "Currency must be ISO 4217"}'
        "429":
          description: "Rate limit exceeded"
          headers:
            Retry-After:
              description: "Seconds until next request allowed"

  standards:
    - all_enums_documented: true
    - all_error_codes_listed: true
    - pagination_documented: true
    - idempotency_key_documented_for_mutations: true
    - deprecation_headers_documented: true
    - webhook_schemas_included: true
```

---

## Quick Compliance & Governance Checklist

Before deploying ANY system to production:

- [ ] Data classification applied to all data stores and API fields?
- [ ] GDPR data minimization manifest complete for all PII fields?
- [ ] Right to erasure implemented with propagation to all downstream systems?
- [ ] Data residency controls enforced (OPA / infrastructure policy)?
- [ ] SonarQube quality gate passes (coverage >= 80%, 0 critical/blocker issues)?
- [ ] OpenAPI diff run — no undeclared breaking changes?
- [ ] API version sunset date documented for deprecated endpoints?
- [ ] Audit logging covers all data mutations + sensitive reads with HMAC integrity?
- [ ] Audit storage is append-only with separate DB credentials?
- [ ] SIEM forwarding configured for security events?
- [ ] RBAC/ABAC policies reviewed within last quarter?
- [ ] Privileged access requires dual approval and time-bound sessions?
- [ ] Least privilege enforced in all IAM policies (no wildcards)?
- [ ] OPA/Rego policies testing all infrastructure changes in CI/CD?
- [ ] SBOM generated, signed, and scanned for every release?
- [ ] Third-party vendors have current security assessment (< 12 months)?
- [ ] Incident response runbooks exist, tested, and reviewed quarterly?
- [ ] Breach notification SLA tracked and tested?
- [ ] ADR written for every non-obvious architectural decision?
- [ ] API documentation includes all error codes, examples, and deprecation headers?
