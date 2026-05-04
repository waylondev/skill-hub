# Phase 17: Production Compliance

## Objective

Ensure the migrated Java application meets all regulatory compliance frameworks applicable to the original COBOL system. Generate security configurations, audit logging templates, and compliance mappings for PCI-DSS, HIPAA, SOX, GDPR/CCPA, and FedRAMP. Each framework must map to concrete Spring Security and infrastructure configurations.

## Input

- Phase 6: Architecture Blueprint — security zones and trust boundaries
- Phase 8: Security Mapping (`SecurityConfig.java`, JWT filter)
- Phase 9: Generated Code (all service classes with `@PreAuthorize`)
- Phase 13: Docker & Kubernetes (infrastructure hardening)

## Deliverables

- `17-production-compliance/pci-dss-compliance.md` — PCI-DSS 4.0 mapping
- `17-production-compliance/hipaa-compliance.md` — HIPAA/HITECH mapping
- `17-production-compliance/sox-compliance.md` — SOX IT controls mapping
- `17-production-compliance/gdpr-ccpa-compliance.md` — GDPR/CCPA PII handling
- `17-production-compliance/fedramp-compliance.md` — FedRAMP K8s hardening
- `17-production-compliance/compliance-matrix.xlsx` — Combined compliance checklist

## PCI-DSS 4.0 Compliance Mapping

### Requirement → Spring Security Implementation

| PCI-DSS 4.0 Requirement | COBOL Mainframe Equivalent | Java/Spring Implementation |
|--------------------------|---------------------------|---------------------------|
| **Req 3.4** — Render PAN unreadable | RACF dataset protection, encryption at rest | `@Convert(converter = PanEncryptor.class)` with AES-256-GCM on PAN column. `spring.datasource.hikari.data-source-properties.encrypt=true` |
| **Req 6.5** — Secure application development | Change control on COBOL compiles | CI/CD pipeline (Phase 12) with mandatory SonarQube quality gate, OWASP dependency check |
| **Req 7.1** — Limit access by need-to-know | RACF user profiles, CICS transaction security | `@PreAuthorize("hasRole('CARD_READ')")` on controllers. `SecurityFilterChain` with method-level security |
| **Req 7.2** — Access control system | CICS SIT transaction security | JWT Bearer token with role claims. Token expiration: 15min access, 8h refresh |
| **Req 8.2** — Unique user identification | RACF USERID, CICS sign-on | BCrypt password hashing, account lockout after 5 failed attempts, MFA via TOTP |
| **Req 10.2** — Automated audit trails | SMF type 80 records, CICS journal | `@EnableJpaAuditing` with `@CreatedBy`/`@LastModifiedBy`. Audit table for all sensitive operations |
| **Req 10.5** — Secure audit trail storage | SMF datasets with WRITE-ONLY | Audit logs to append-only table. `GRANT INSERT ON audit_log TO app_user; REVOKE DELETE, UPDATE ON audit_log FROM app_user;` |
| **Req 11.3** — Penetration testing | Annual mainframe pentest | OWASP ZAP in CI/CD. Dependency scanning with `mvn dependency-check:check` |
| **Req 12.3** — Risk assessment | BIA (Business Impact Analysis) | Phase 6 architecture risk matrix. Threat modeling via STRIDE on migrated API endpoints |

### PAN Encryption Configuration

```java
// PCI-DSS 3.4: Render PAN unreadable
@Converter
public class PanEncryptor implements AttributeConverter<String, String> {

    private static final String ALGORITHM = "AES/GCM/NoPadding";
    private static final String KEY_ENV = "PAN_ENCRYPTION_KEY";

    @Override
    public String convertToDatabaseColumn(String pan) {
        if (pan == null) return null;
        return encrypt(pan);
    }

    @Override
    public String convertToEntityAttribute(String dbData) {
        if (dbData == null) return null;
        return decrypt(dbData);
    }

    public static String maskForDisplay(String pan) {
        if (pan == null || pan.length() < 6) return "****";
        return pan.substring(0, 6) + "******" + pan.substring(pan.length() - 4);
    }
}
```

### PCI-DSS Audit Logging

```java
// PCI-DSS 10.2: Automated audit trail
@Entity
@Table(name = "audit_log")
public class AuditLog {
    @Id @GeneratedValue(strategy = GenerationType.SEQUENCE)
    private Long id;

    @Column(nullable = false)
    private String userId;

    @Column(nullable = false)
    private String action;           // READ, CREATE, UPDATE, DELETE

    @Column(nullable = false)
    private String resource;          // CARD/ACCOUNT/TRANSACTION

    @Column(nullable = false)
    private String resourceId;

    @Column(nullable = false)
    private String ipAddress;

    @Column(nullable = false)
    private LocalDateTime timestamp;

    @Column(nullable = false)
    private Boolean success;

    @Column(columnDefinition = "JSONB")
    private String previousState;     // Before image for UPDATE/DELETE

    @Column(columnDefinition = "JSONB")
    private String newState;          // After image for CREATE/UPDATE
}

@Repository
public interface AuditLogRepository extends JpaRepository<AuditLog, Long> {
    // Write-only from application perspective
    @Modifying
    @Query(nativeQuery = true, value = "INSERT INTO audit_log (...) VALUES (...)")
    void write(AuditLog entry);

    // Read permitted for compliance reporting only
    @PreAuthorize("hasRole('COMPLIANCE')")
    List<AuditLog> findByResourceAndResourceId(String resource, String resourceId);
}
```

## HIPAA/HITECH Compliance Mapping

### Requirement → Implementation

| HIPAA Requirement | COBOL Equivalent | Java/Spring Implementation |
|-------------------|-----------------|---------------------------|
| **164.312(a)(1)** — Access control | RACF + CICS transaction security | RBAC via `@PreAuthorize`. `hasRole('PHI_READ')`, `hasRole('PHI_WRITE')` |
| **164.312(a)(2)(iv)** — Encryption at rest | DASD encryption (IBM Pervasive Encryption) | PostgreSQL `pgcrypto` extension or column-level encryption. `@Convert` for PHI fields |
| **164.312(b)** — Audit controls | SMF type 80, CICS monitoring | Extended `AuditLog` table with PHI access flag. All PHI reads logged with purpose |
| **164.312(c)(1)** — Integrity controls | VSAM VERIFY, backup verification | `@Version` for optimistic locking. `CHECKSUM` validation in data migration (Phase 18) |
| **164.312(d)** — Authentication | RACF password, CICS sign-on | BCrypt + MFA TOTP. PHI access requires re-authentication every 15 minutes |
| **164.312(e)(1)** — Transmission security | SNA/SSL for CICS sockets | TLS 1.3 for all REST endpoints. Mutual TLS for service-to-service PHI transfers |
| **164.310(d)(1)** — Device controls | Tape management, offsite rotation | Kubernetes `PersistentVolume` with storage class encryption. Backup to encrypted S3 bucket |

### PHI Field Annotation

```java
// HIPAA: Mark all PHI fields
@Target(ElementType.FIELD)
@Retention(RetentionPolicy.RUNTIME)
public @interface ProtectedHealthInformation {
    String category() default "GENERAL";
    boolean requireAuditOnRead() default true;
}

// Usage in Entity
@Entity
public class PatientRecord {
    @ProtectedHealthInformation(category = "IDENTIFIER")
    @Column(name = "patient_name")
    private String patientName;

    @ProtectedHealthInformation(category = "IDENTIFIER")
    @Column(name = "ssn")
    @Convert(converter = SsnEncryptor.class)
    private String ssn;

    @ProtectedHealthInformation(category = "CLINICAL")
    @Column(name = "diagnosis_code", length = 10)
    private String diagnosisCode;
}
```

## SOX Compliance Mapping

### IT General Controls → Implementation

| SOX ITGC Domain | COBOL Mainframe Control | Java Implementation |
|----------------|------------------------|-------------------|
| **Change Management** | SCLM/Endevor for code promotion | PR → Code Review → CI/CD → Approval → Deploy. All changes traceable via git history |
| **Access Control** | RACF + CICS transaction security + dataset profiles | RBAC with segregated duties. Developer ≠ Approver ≠ Deployer |
| **IT Operations** | Console operator procedures, IPL schedule | Kubernetes health probes, automated pod restarts, incident response runbooks |
| **Program Development** | COBOL compile listing review | SonarQube quality gate (Phase 12). Mandatory code review with at least 1 senior approval |
| **Program Change** | Emergency fix procedure, backout plan | Hotfix branch → expedited review → canary deploy → full rollout. Git revert for rollback |

### Segregation of Duties Configuration

```yaml
# application.yml — SOX compliance
app:
  sox:
    segregated-duties:
      developer-role: DEVELOPER        # Write code, create PRs
      reviewer-role: REVIEWER          # Approve PRs
      deployer-role: DEPLOYER          # Trigger deployments
      auditor-role: COMPLIANCE          # Read audit logs, no write access

      rules:
        - reviewer-cannot-deploy: true
        - developer-cannot-self-approve: true
        - deployer-cannot-modify-code: true
```

### Financial Data Integrity

```java
// SOX: Immutable ledger pattern for financial transactions
@Entity
@Table(name = "financial_ledger")
public class FinancialLedgerEntry {
    @Id @GeneratedValue
    private Long id;

    @Column(nullable = false, updatable = false)
    private String transactionId;     // Immutable

    @Column(nullable = false, updatable = false, precision = 19, scale = 4)
    private BigDecimal amount;        // Immutable

    @Column(nullable = false, updatable = false)
    private String accountId;         // Immutable

    @Column(nullable = false, updatable = false)
    private String entryType;         // DEBIT/CREDIT — immutable

    @Column(nullable = false, updatable = false)
    private LocalDateTime postedAt;   // Immutable

    @Column(nullable = false)
    private String hashChain;         // SHA-256(prev_hash + this_entry)

    // Source: COBOL COMPUTE BALANCE = BALANCE + AMOUNT
    // Now: Account balance is computed as SUM(all ledger entries) for auditability
}
```

## GDPR/CCPA Compliance Mapping

### PII Handling Requirements

| GDPR/CCPA Requirement | Implementation |
|----------------------|----------------|
| **Right to Access (Art.15)** | `GET /api/v1/subject-access/{userId}` — returns all PII in machine-readable JSON |
| **Right to Erasure (Art.17)** | `DELETE /api/v1/pii/{userId}` — soft-delete PII, retain audit trail without PII content |
| **Right to Data Portability (Art.20)** | `GET /api/v1/data-export/{userId}` — export in CSV/JSON/XML format |
| **CCPA Do Not Sell** | `@RequestHeader("X-CCPA-Opt-Out")` — intercept in filter, suppress tracking PII |
| **Data Minimization** | `@Column(length=N)` with strict validation. No `TEXT` columns for PII. Auto-purge PII > retention period |
| **Consent Management** | `consent_ledger` table with granular consent flags. API consent enforcement via `@PreAuthorize("#request.consent == true")` |

### PII Anonymization for Non-Production

```java
// GDPR: Anonymize PII in DEV/STAGING environments
@Component
@Profile({"dev", "staging"})
public class PiiAnonymizer implements ApplicationListener<ContextRefreshedEvent> {

    @Override
    public void onApplicationEvent(ContextRefreshedEvent event) {
        // Replace real PII with anonymized test data
        patientRecordRepository.findAll().forEach(record -> {
            record.setPatientName("ANONYMIZED_" + record.getId());
            record.setSsn("000-00-" + String.format("%04d", record.getId() % 10000));
            patientRecordRepository.save(record);
        });
    }
}
```

## FedRAMP Compliance Mapping

### Kubernetes Hardening Requirements

| FedRAMP Control | K8s Implementation |
|----------------|-------------------|
| **AC-2** — Account Management | Kubernetes RBAC + OIDC provider (Keycloak) for cluster access. No long-lived kubeconfig tokens |
| **AU-2** — Audit Events | Kubernetes audit policy logging + Falco runtime security. Ship all logs to SIEM |
| **CM-6** — Configuration Settings | Pod Security Standards (`restricted`). `readOnlyRootFilesystem: true`, `allowPrivilegeEscalation: false` |
| **SC-7** — Boundary Protection | NetworkPolicy (deny-all + allow specific). Istio/Ambient mesh for mTLS between services |
| **SC-8** — Transmission Integrity | TLS 1.3 via cert-manager. Ingress with automatic Let's Encrypt certificates |
| **SI-4** — Information System Monitoring | Prometheus + Grafana + Fluentd → ELK stack for centralized monitoring |

### FedRAMP Hardened Pod Security

```yaml
# deployment.yaml additions for FedRAMP
spec:
  template:
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1001
        fsGroup: 1001
      containers:
      - name: app
        securityContext:
          readOnlyRootFilesystem: true
          allowPrivilegeEscalation: false
          runAsNonRoot: true
          capabilities:
            drop:
            - ALL
        volumeMounts:
        - name: tmp
          mountPath: /tmp
        - name: logs
          mountPath: /var/log/app
      volumes:
      - name: tmp
        emptyDir: {}
      - name: logs
        emptyDir: {}
```

### Network Policy (Zero Trust)

```yaml
# network-policy.yaml — deny all, allow specific
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-app-to-database
spec:
  podSelector:
    matchLabels:
      app: cobol-migration
  policyTypes:
  - Egress
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: postgres
    ports:
    - port: 5432
      protocol: TCP
```

## Execution Steps

### Step 1: Identify Applicable Frameworks

Determine which compliance frameworks apply:
- **PCI-DSS**: Always required if PAN/cardholder data processed
- **HIPAA**: Required if ePHI processed
- **SOX**: Required for publicly traded companies with financial systems
- **GDPR**: Required if EU personal data processed
- **CCPA**: Required if California consumer data processed
- **FedRAMP**: Required for US federal government systems

### Step 2: Generate Per-Framework Compliance Documents

For each applicable framework, produce a compliance document (`pci-dss-compliance.md`, `hipaa-compliance.md`, etc.) with the mapping tables and configuration examples above.

### Step 3: Implement Security Configurations

Apply framework-specific configurations to the generated codebase:
- PAN/PII encryption converters
- Audit logging configuration
- Access control matrices
- Data retention and anonymization rules

### Step 4: Generate Combined Compliance Matrix

Produce `compliance-matrix.xlsx` with all frameworks as rows and controls as columns. Mark which controls overlap across frameworks.

### Step 5: Perform Compliance Validation

- Run OWASP ZAP scan against DEV environment
- Verify SonarQube security rules pass
- Validate encryption at rest (query DB directly)
- Test audit log immutability

## Quality Gate

- [ ] All applicable compliance frameworks identified and documented
- [ ] PAN/PII/sensitive fields encrypted at rest with `@Convert` or `pgcrypto`
- [ ] Audit logging implemented for all CRUD operations on protected resources
- [ ] Audit logs stored in append-only tables (no UPDATE/DELETE grants)
- [ ] RBAC enforced at controller and service layer with `@PreAuthorize`
- [ ] Non-production environments have PII anonymized automatically
- [ ] Kubernetes pods run as non-root with read-only root filesystem
- [ ] NetworkPolicy configured (default-deny with specific allows)
- [ ] TLS 1.3 enforced on all ingress endpoints
- [ ] OWASP ZAP scan passed with no high/critical findings
- [ ] Consent management implemented if GDPR/CCPA applicable
- [ ] Right to erasure and data portability endpoints tested
- [ ] `_state-snapshot.json` updated to `{'phase':17,'status':'complete'}`
