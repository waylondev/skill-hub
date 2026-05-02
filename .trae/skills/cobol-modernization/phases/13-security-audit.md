# Phase 8d: Security Audit Report

> **DEPENDS ON:** Phase 4 (COPYBOOK) + Phase 5 (Program Logic) + Phase 6 (Architecture)  
> **OUTPUT:** `08-deliverables/security-audit.md`

## Objective

Produce a comprehensive security audit report that identifies ALL security anomalies in the COBOL source code and provides detailed remediation strategies for the Java/Spring Boot target environment.

## Why This Phase Is Critical

- COBOL systems were designed in an era of closed mainframe networks — many practices violate modern security standards
- Plaintext passwords (as found in CardDemo USRSEC) are a critical vulnerability
- PII data (SSN, DOB) travels in cleartext CommArea between CICS programs
- MQ messages may contain card numbers without encryption
- RACF security profiles need explicit mapping to Spring Security roles
- PCI-DSS compliance requires documented security controls

## Audit Categories

### 1. Password & Authentication

| Issue | Severity | Source | Current Behavior | Remediation |
|-------|---------|--------|-----------------|------------|
| Plaintext password storage | **CRITICAL** | USRSEC VSAM (CVTRA07Y.cpy) — SEC-USR-PWD PIC X(8) | Passwords stored and compared as-is: `IF SEC-USR-PWD = USER-PASSWORD-I` | BCrypt hashing: `PasswordEncoder.matches(raw, hash)`. Migration: hash-on-next-login strategy |
| Fixed 8-char password | **HIGH** | COSGN00C.cbl + COUSR01C.cbl | Length enforced but no complexity | Enforce 12+ chars, uppercase, digit, special char |
| No password history | **MEDIUM** | — | No reuse prevention | Password history table, last 5 passwords |
| No account lockout | **MEDIUM** | — | Unlimited login attempts | Account lock after 5 failures, 15-minute cooldown |

### 2. Data Encryption

| Issue | Severity | Source | Current Behavior | Remediation |
|-------|---------|--------|-----------------|------------|
| SSN stored in plaintext | **HIGH** | CVCUS01Y.cpy — CUST-SSN PIC X(9) | Stored as-is, transmitted in CommArea | Column-level encryption (pgcrypto) or application-level @Convert |
| Card numbers in CommArea | **MEDIUM** | COCOM01Y.cpy — CDEMO-CARD-NUM | Transmitted between CICS programs unencrypted | Tokenization or field-level encryption |
| No MQ message encryption | **MEDIUM** | Sub-App 1 COPAUA0C — MQPUT1 | Authorization request/response messages in CSV plaintext | TLS for MQ channels, encrypt card number in payload |
| No data-at-rest encryption | **MEDIUM** | ALL VSAM files | VSAM KSDS stored as DASD without encryption | AWS RDS encryption at rest (KMS) |

### 3. Access Control

| Issue | Severity | Source | Current Behavior | Remediation |
|-------|---------|--------|-----------------|------------|
| Single USER/ADMIN role | **LOW** | CSUSR01Y.cpy — 88 ADMIN('A') / USER('U') | Binary role model | Fine-grained RBAC: ROLE_ADMIN, ROLE_USER, ROLE_BATCH, ROLE_AUDIT |
| No resource-level auth | **MEDIUM** | ALL CICS programs | Any USER can view any account — no ownership check | `@PreAuthorize("@accountSecurity.isOwner(#acctId)")` |
| Admin can do everything | **LOW** | COADM01C dispatches all admin | No separation of duties | Split: UserAdmin, TranTypeAdmin, AuthViewer roles |
| No API rate limiting | **MEDIUM** | — | No throttling | Spring Cloud Gateway RateLimiter: 5 req/sec per user |

### 4. Audit & Logging

| Issue | Severity | Source | Current Behavior | Remediation |
|-------|---------|--------|-----------------|------------|
| Error logs to TD queue only | **LOW** | CCPAUERY.cpy — WRITEQ TD CSSL | Errors go to transient CICS TD queue | Structured JSON logging to centralized ELK/Splunk |
| No access audit log | **MEDIUM** | — | No record of who accessed what | Spring Security AuditEventPublisher + audit table |
| No transaction log immutability | **LOW** | COPAUA0C — IMS ISRT | Auth logs in IMS, mutable | Append-only audit table with hash chain |

### 5. Input Validation & Injection

| Issue | Severity | Source | Current Behavior | Remediation |
|-------|---------|--------|-----------------|------------|
| No SQL injection risk (COBOL) | **N/A** | — | COBOL static SQL is precompiled | JPA parameterized queries, no native SQL with concatenation |
| No XSS protection | **N/A** | — | Terminal-based 3270, no web | Output encoding on web frontend |
| Numeric validation | **LOW** | ALL CICS programs | IF NOT NUMERIC checks exist | @Pattern + @Digits + type-based validation |
| No file upload validation | **N/A** | — | No file upload in CICS | If added: file type/size/content-type validation |

### 6. Sub-Application Specific

| Issue | Severity | Source | Current Behavior | Remediation |
|-------|---------|--------|-----------------|------------|
| MQ auth trigger without validation | **LOW** | COPAUA0C — RETRIEVE MQTM | Any MQ trigger can invoke auth program | Verify MQ trigger source before processing |
| IMS segment auth via PSB | **LOW** | PSBPAUTL.psb | IMS PSB controls segment access | JPA `@PreAuthorize` on auth repository methods |
| DB2 connect without explicit user context | **LOW** | COTRTLIC | CICS passes region user | Service account per module with least privilege |

## Security Control Matrix

```markdown
| Control | COBOL/CICS | Spring Boot/Cloud | Status |
|---------|-----------|-------------------|--------|
| Authentication | RACF signon + USRSEC lookup | JWT + Spring Security + BCrypt | NEEDS MIGRATION |
| Authorization | RACF transaction security | @PreAuthorize + method security | NEEDS MIGRATION |
| Data encryption (transit) | SNA/VTAM (terminal) | TLS 1.3 (HTTPS + MQ TLS) | NEW |
| Data encryption (at rest) | None | AWS RDS encryption (KMS) + Column encryption | NEW |
| Audit logging | CICS TD queues + SMF | Structured JSON → ELK/Splunk | ENHANCED |
| Rate limiting | CICS MAXTASK | Spring Cloud Gateway RateLimiter | NEW |
| Session management | CICS pseudo-conversational (CommArea) | Stateless JWT + Redis token cache | REDESIGNED |
| Password policy | Min 8 chars, plaintext | Min 12 chars, BCrypt, history, expiry | ENHANCED |
| PCI-DSS compliance | Unknown | PCI-DSS 4.0 controls mapped | NEW |
```

## COBOL → Java Security Annotations Map

| COBOL Pattern | Java Annotation |
|--------------|----------------|
| `IF SEC-USR-TYPE = 'A'` | `@PreAuthorize("hasRole('ADMIN')")` |
| `IF WS-INPUT-INVALID` | `@Valid` + `MethodArgumentNotValidException` |
| `WRITEQ TD CSSL` on error | `@Slf4j` + `log.error()` + `@ExceptionHandler` |
| `EXEC CICS SYNCPOINT` | `@Transactional` + `@Version` for optimistic locking |
| `EXEC CICS READ UPDATE` | `@Lock(PESSIMISTIC_WRITE)` |
| `RACF SIGNON` | `POST /api/v1/auth/login` → JWT token |

## Remediation Priority Matrix

| Priority | Issue | Impact | Effort | Must Do Before |
|----------|-------|--------|--------|---------------|
| **P0** | Plaintext passwords → BCrypt | CRITICAL | 1 day | Production deployment |
| **P0** | HTTPS/TLS on all endpoints | CRITICAL | 2 days | Any external exposure |
| **P1** | SSN encryption at rest | HIGH | 2 days | Data migration |
| **P1** | Fine-grained RBAC | HIGH | 3 days | Admin module go-live |
| **P2** | API rate limiting | MEDIUM | 1 day | Public API exposure |
| **P2** | Audit logging | MEDIUM | 2 days | Compliance audit |
| **P3** | Account lockout | MEDIUM | 1 day | Before UAT |
| **P3** | Password complexity policy | MEDIUM | 1 day | Before UAT |

## Execution Steps

### Step 1: Scan for Security Anomalies

Grep ALL COBOL source for:
- `PIC X(N)` fields matching SSN/DOB/CC patterns
- `PASSWORD`/`PWD`/`SEC-USR-PWD` fields
- `WRITEQ`/`MQPUT` with sensitive data
- Missing `IF NOT NUMERIC` checks on input fields

### Step 2: Classify by Severity

Assign CRITICAL/HIGH/MEDIUM/LOW using OWASP risk rating.

### Step 3: Generate Remediation Plan

For each issue, document EXACT Java code fix.

### Step 4: Export

Write `08-deliverables/security-audit.md`.

## Quality Gate

- [ ] ALL password-related fields identified and documented
- [ ] ALL PII fields identified with encryption plan
- [ ] ALL access control points mapped to @PreAuthorize
- [ ] ALL error logging points mapped to Spring ExceptionHandler
- [ ] Remediation plan includes effort estimates
- [ ] PCI-DSS controls mapped where applicable
