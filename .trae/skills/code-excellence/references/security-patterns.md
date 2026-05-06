# Security Patterns — Expert Level

## Purpose

Production-grade security patterns that every architect must embed into code generation.
Covers the OWASP Top 10 to code pattern mapping, JWT lifecycle, authorization models,
and audit requirements.

---

## OWASP Top 10 → Code Pattern Mapping

| OWASP Risk | Code Pattern | Anti-Pattern Ref |
|------------|-------------|-----------------|
| **A1: Broken Access Control** | Authorization at service layer, not controller. Fail-closed by default. | AP-4, AP-27 |
| **A2: Cryptographic Failures** | Never roll your own crypto. Use vetted libraries (BCrypt, Argon2). TOTP for 2FA. | — |
| **A3: Injection** | Parameterized queries 100%. ORM with named params. Never string concat for SQL/OS/HTML. | AP-27 |
| **A4: Insecure Design** | Threat modeling in design phase. Security review against this file. Input whitelisting. | AP-1, AP-2 |
| **A5: Security Misconfiguration** | Fail-fast config validation at startup. No default passwords. CSP headers. | AP-6, AP-7 |
| **A6: Vulnerable Components** | Dependabot/Renovate in CI. SBOM (CycloneDX). Version pinning. | — |
| **A7: Auth Failures** | JWT lifecycle management below. Rate limit login. Breached password detection. | AP-8, AP-20 |
| **A8: Software & Data Integrity** | Checksum verification for dependencies. Signed commits. Artifact signing. | — |
| **A9: Logging & Monitoring** | Security events to separate audit log. Alert on auth failures. Never log secrets (AP-20). | AP-20 |
| **A10: SSRF** | URL whitelisting. Disable HTTP redirect following on untrusted URLs. Network egress rules. | AP-27 |

---

## Pattern: Authorization — RBAC vs ABAC

### RBAC (Role-Based Access Control)

**Use when**: Permissions are role-centric. Roles map to job functions. Changes are infrequent.

```java
@Target(METHOD)
@Retention(RUNTIME)
public @interface RequireRole {
    Role[] value();
}

// Check at SERVICE layer, not controller
@Service
public class OrderService {
    @RequireRole({ADMIN, ORDER_MANAGER})
    public Order cancel(Long orderId) {
        // Authorization checked by AOP interceptor BEFORE business logic
        // Fail-CLOSED: if interceptor fails, method never executes
    }
}

// Interceptor — single authorization enforcement point
@Aspect
@Component
public class AuthorizationAspect {
    @Around("@annotation(requireRole)")
    public Object check(ProceedingJoinPoint joinPoint, RequireRole requireRole) {
        var user = SecurityContext.getCurrentUser();
        if (user == null) throw new UnauthorizedException("Not authenticated");
        if (!user.hasAnyRole(requireRole.value()))
            throw new ForbiddenException("User lacks required role: " + Arrays.toString(requireRole.value()));
        return joinPoint.proceed();
    }
}
```

### ABAC (Attribute-Based Access Control)

**Use when**: Permissions depend on resource attributes + user attributes + context. Fine-grained rules change independently of role assignment.

```java
public interface Policy {
    boolean evaluate(User user, Resource resource, Action action, Map<String, Object> context);
}

public record CanCancelOwnOrder() implements Policy {
    @Override
    public boolean evaluate(User user, Resource resource, Action action, Map<String, Object> ctx) {
        // User can cancel if: (is ORDER_MANAGER) OR (owns the order AND order is PENDING)
        if (user.hasRole(ORDER_MANAGER)) return true;
        if (action != Action.CANCEL) return false;
        var order = (Order) resource;
        return order.userId().equals(user.id()) && order.status() == PENDING;
    }
}

// Composable policies
var policy = new CanCancelOwnOrder()
    .or(new CanIfAdmin());

if (!policy.evaluate(currentUser, order, Action.CANCEL, Map.of())) {
    throw new ForbiddenException("Cannot cancel order " + order.id());
}
```

---

## Pattern: JWT Lifecycle Management

### Issuance — Access Token + Refresh Token

```java
@Service
public class TokenService {
    private static final Duration ACCESS_TOKEN_TTL = Duration.ofMinutes(15);
    private static final Duration REFRESH_TOKEN_TTL = Duration.ofDays(7);

    public TokenPair issue(User user) {
        var accessToken = Jwts.builder()
            .subject(user.id().toString())
            .claim("roles", user.roles())
            .issuedAt(Instant.now())
            .expiration(Instant.now().plus(ACCESS_TOKEN_TTL))
            .signWith(accessKey)  // RS256/ES256 — asymmetric, service only signs
            .compact();

        var refreshToken = generateRefreshToken(user);
        refreshTokenStore.save(user.id(), refreshToken, REFRESH_TOKEN_TTL);
        return new TokenPair(accessToken, refreshToken);
    }
}
```

### Refresh — Rotation (Invalidate Old on Use)

```java
public TokenPair refresh(String oldRefreshToken) {
    var entry = refreshTokenStore.validateAndConsume(oldRefreshToken);
    // Old refresh token is immediately invalidated (rotation)
    // If old refresh token is reused → potential token theft → revoke ALL tokens for this user
    if (entry.wasAlreadyUsed()) {
        refreshTokenStore.revokeAllForUser(entry.userId());
        log.warn("Refresh token reuse detected for user {} — all sessions revoked", entry.userId());
        throw new SecurityException("Token reuse detected");
    }
    var user = userRepo.findById(entry.userId()).orElseThrow();
    return issue(user); // new pair issued, old refresh consumed
}
```

### Revocation

```java
// Revoke ALL tokens (password change, account lock)
refreshTokenStore.revokeAllForUser(userId);

// Per-token revocation (user logs out from one device)
refreshTokenStore.revoke(userId, refreshTokenId);

// Blacklist check on every request (for critical operations)
if (tokenBlacklist.contains(accessToken.jti())) {
    throw new UnauthorizedException("Token revoked");
}
```

### Token Storage — Client-Side Rules

| Client | Access Token | Refresh Token |
|--------|-------------|---------------|
| **SPA (browser)** | Memory only (JS variable) | httpOnly, Secure, SameSite=Strict cookie |
| **Mobile** | Secure enclave (iOS Keychain / Android Keystore) | Secure enclave |
| **Server-to-server** | Environment variable / Vault | N/A — client credentials, no refresh |

---

## Pattern: Audit Logging (Immutable Trail)

**Use when**: Compliance requires tamper-proof logging of who did what and when.
Must survive transaction rollback.

```java
@Service
public class AuditService {
    // Uses REQUIRES_NEW — audit MUST persist even if business transaction rolls back
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void record(AuditEvent event) {
        auditRepo.save(new AuditRecord(
            event.traceId(),
            event.actorId(),        // who
            event.actorRoles(),     // with what authority
            event.action(),         // CREATE/UPDATE/DELETE/EXPORT
            event.resourceType(),   // ORDER/USER/PAYMENT
            event.resourceId(),     // which resource
            event.beforeSnapshot(), // what was the state before
            event.afterSnapshot(),  // what did it become
            event.clientIp(),       // where from
            event.timestamp()       // when
        ));
    }
}

// Critical business events automatically audited
@Aspect
@Component
public class AuditAspect {
    @Around("@annotation(Auditable)")
    public Object audit(ProceedingJoinPoint jp) {
        var beforeState = captureState(jp);
        try {
            var result = jp.proceed();
            auditService.record(AuditEvent.success(currentUser(), jp, beforeState, result));
            return result;
        } catch (Exception e) {
            auditService.record(AuditEvent.failure(currentUser(), jp, beforeState, e));
            throw e; // audit happened, still propagate the error
        }
    }
}
```

**Audit storage requirements**:
- **Append-only**: No UPDATE, no DELETE on audit records
- **Separate database credentials**: App user can INSERT, no SELECT/UPDATE/DELETE
- **Immutable at infrastructure level**: WORM storage (Write Once Read Many), database-level restrictions
- **SIEM integration**: Forward audit events to Splunk/ELK for correlation and alerting

---

## Pattern: Sensitive Data Encryption

### Classification → Strategy

| Classification | Strategy | Example |
|---------------|----------|---------|
| **Public** | No encryption | Product name, price |
| **Internal** | No encryption, access controlled | Business metrics |
| **Confidential** | Encrypt at rest (DB column-level) | Email, phone, address |
| **Restricted** | Encrypt at rest + application-level + KMS | Credit card, SSN, passport # |

```java
// Column-level encryption for PII
@Entity
public class User {
    @Id private Long id;
    private String name; // public

    @Convert(converter = AttributeEncryptor.class)
    private String email; // encrypted at rest

    @Convert(converter = AttributeEncryptor.class)
    private String phoneNumber; // encrypted at rest
}

// Application-level encryption with KMS
public record SensitiveField<T>(
    @JsonIgnore T decrypted,
    String encryptedBlob,
    String kmsKeyId
) {
    public static SensitiveField<CreditCard> protect(CreditCard card, KmsClient kms) {
        var dataKey = kms.generateDataKey(kmsKeyId);
        var encrypted = AesGcm.encrypt(card.toBytes(), dataKey.plaintext());
        return new SensitiveField<>(null, encrypted, dataKey.encryptedKey());
    }

    public CreditCard reveal(KmsClient kms) {
        var plaintextKey = kms.decrypt(kmsKeyId, encryptedBlob);
        return CreditCard.from(AesGcm.decrypt(encryptedBlob, plaintextKey));
    }
}
```

---

## Pattern: Rate Limiting (Production Implementation)

Expanding on the `patterns.md` Token Bucket with per-user/IP scoping and distribution.

```java
@Service
public class DistributedRateLimiter {
    private final RedisTemplate<String, String> redis;

    public boolean tryAcquire(String key, long capacity, double refillRate) {
        // Lua script for atomic token bucket check in Redis
        // Single round-trip, race-condition free, works across instances
        String script = """
            local tokens = tonumber(redis.call('hget', KEYS[1], 'tokens'))
            local last = tonumber(redis.call('hget', KEYS[1], 'lastRefill'))
            if tokens == nil then tokens = tonumber(ARGV[1]); last = tonumber(ARGV[3]); end
            local now = tonumber(ARGV[3])
            local elapsed = (now - last) / 1000.0
            tokens = math.min(tonumber(ARGV[1]), tokens + elapsed * tonumber(ARGV[2]))
            if tokens >= 1 then
                redis.call('hset', KEYS[1], 'tokens', tokens - 1, 'lastRefill', now)
                redis.call('expire', KEYS[1], ARGV[4])
                return 1
            end
            redis.call('hset', KEYS[1], 'tokens', tokens, 'lastRefill', now)
            redis.call('expire', KEYS[1], ARGV[4])
            return 0
            """;
        var result = redis.execute(script, key, capacity, refillRate, System.currentTimeMillis(), 3600);
        return (Long) result == 1L;
    }
}

// Layered enforcement
// L1: IP-based (100 req/s per IP) — stops basic DoS
// L2: User-based (10 req/s per user) — per-user quota
// L3: Endpoint-based (POST /payments: 1 req/s) — critical endpoint throttle
```

---

## Pattern: Defense in Depth — Input Validation Layers

```
Request
  → L1: Transport (TLS 1.3, HSTS, certificate pinning)
  → L2: Network (WAF, DDoS protection)
  → L3: API Gateway (Rate limiting, request size cap, header validation)
  → L4: Controller (Bean Validation: @NotNull, @Size, @Pattern, whitelist fields)
  → L5: Service (Business rule validation: user exists, product active, account funded)
  → L6: Repository (Parameterized query, entity constraint: unique, FK, not-null)
  → L7: Database (Row-level security, column encryption, audit triggers)
```

```java
// L4: Controller level — syntactic validation
public record CreatePaymentRequest(
    @NotNull Long orderId,
    @NotBlank @Size(min = 16, max = 16) String cardNumberMasked, // NEVER full card
    @NotNull @Min(1) @Max(100000) BigDecimal amount,
    @Pattern(regexp = "^[A-Z]{3}$") String currency,
    @NotNull UUID idempotencyKey  // external input, validated
) {}

// L5: Service level — semantic validation
@PreAuthorize("hasRole('CUSTOMER') AND #request.userId() == authentication.principal.id")
public PaymentResult charge(CreatePaymentRequest request) {
    var order = orderRepo.findById(request.orderId())
        .orElseThrow(() -> new OrderNotFoundException(request.orderId()));
    if (order.status() != PENDING) throw new InvalidOrderStateException(order.id(), order.status());
    if (order.userId() != currentUser().id()) throw new ForbiddenException("Order belongs to another user");
    return paymentGateway.charge(request);
}
```

---

## Pattern: SAST Integration in CI/CD

**Use when**: Every commit and pull request must be scanned for vulnerabilities before reaching production. SAST (Static Application Security Testing) analyzes source code without execution.

### SonarQube — Quality Gate Enforcement

```yaml
# .github/workflows/sast-sonarqube.yml
name: SAST — SonarQube
on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  sonar:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0  # required for blame/lineage

      - name: Set up JDK 21
        uses: actions/setup-java@v4
        with:
          java-version: '21'
          distribution: 'temurin'

      - name: Cache SonarQube packages
        uses: actions/cache@v4
        with:
          path: ~/.sonar/cache
          key: ${{ runner.os }}-sonar

      - name: Build and analyze
        env:
          SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
        run: |
          ./mvnw verify sonar:sonar \
            -Dsonar.projectKey=myorg_myapp \
            -Dsonar.host.url=${{ vars.SONAR_HOST }} \
            -Dsonar.qualitygate.wait=true \
            -Dsonar.coverage.jacoco.xmlReportPaths=target/site/jacoco/jacoco.xml
```

**Quality Gate rules (minimum)**:
- New issues (blocker/critical) = 0
- Code coverage on new code ≥ 80%
- Duplicated lines on new code ≤ 3%
- Security rating on new code = A

### CodeQL — GitHub-Native Semantic Analysis

```yaml
# .github/workflows/sast-codeql.yml
name: SAST — CodeQL
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  schedule:
    - cron: '0 9 * * 1'  # weekly deep scan

jobs:
  analyze:
    runs-on: ubuntu-latest
    permissions:
      actions: read
      contents: read
      security-events: write
    steps:
      - uses: actions/checkout@v4

      - name: Initialize CodeQL
        uses: github/codeql-action/init@v3
        with:
          languages: java
          queries: security-extended,security-and-quality
          config: |
            paths-ignore:
              - '**/test/**'
              - '**/generated/**'

      - name: Autobuild
        uses: github/codeql-action/autobuild@v3

      - name: Perform CodeQL Analysis
        uses: github/codeql-action/analyze@v3
        with:
          category: "/language:java"
```

### Semgrep — Fast Lightweight Scanning

```yaml
# .github/workflows/sast-semgrep.yml
name: SAST — Semgrep
on:
  push:
    branches: [main, develop]
  pull_request:

jobs:
  semgrep:
    runs-on: ubuntu-latest
    container:
      image: returntocorp/semgrep
    steps:
      - uses: actions/checkout@v4

      - name: Run Semgrep
        run: |
          semgrep ci \
            --config=auto \
            --config=p/owasp-top-ten \
            --config=p/cwe-top-25 \
            --json --output=semgrep-results.json
        env:
          SEMGREP_APP_TOKEN: ${{ secrets.SEMGREP_APP_TOKEN }}

      - name: Upload SARIF
        uses: github/codeql-action/upload-sarif@v3
        if: always()
        with:
          sarif_file: semgrep-results.json
```

**SAST layering strategy**:
| Layer | Tool | Trigger | Purpose |
|-------|------|---------|---------|
| L1 | Semgrep | Every PR | Fast feedback (< 2 min), blocks obvious issues |
| L2 | CodeQL | Every PR + weekly | Deep semantic analysis, CWE coverage |
| L3 | SonarQube | Every push | Quality gate, technical debt tracking, coverage |

---

## Pattern: DAST Automation

**Use when**: The running application must be tested for vulnerabilities from the outside (runtime behavior, auth bypass, misconfigurations). DAST (Dynamic Application Security Testing) requires a deployed instance.

### OWASP ZAP — Baseline Scan in CI

```yaml
# .github/workflows/dast-zap.yml
name: DAST — OWASP ZAP Baseline
on:
  deployment_status:
    types: [success]  # trigger after staging deploy

jobs:
  zap-baseline:
    runs-on: ubuntu-latest
    if: github.event.deployment.environment == 'staging'
    steps:
      - uses: actions/checkout@v4

      - name: ZAP Baseline Scan
        uses: zaproxy/action-baseline@v0.12.0
        with:
          target: ${{ vars.STAGING_URL }}
          rules_file_name: '.zap/rules.tsv'
          cmd_options: '-a'  # include passive scan alerts
          issue_title: 'ZAP Baseline Scan'
          fail_action: true   # fail build on HIGH risk

      - name: Upload ZAP report
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: zap-report
          path: report_*.html
```

```
# .zap/rules.tsv
# format: pluginId  alert  threshold  strength  tag
40012   Cross Site Scripting (Reflected)  HIGH  DEFAULT  xss
40014   Cross Site Scripting (Persistent)  HIGH  DEFAULT  xss
40018   SQL Injection  HIGH  DEFAULT  sqli
90022   Application Error Disclosure  MEDIUM  DEFAULT  info
```

### OWASP ZAP — Authenticated Scan (API)

```yaml
# .github/workflows/dast-zap-authenticated.yml
name: DAST — ZAP Authenticated API Scan
on:
  workflow_dispatch:
  schedule:
    - cron: '0 2 * * *'  # nightly against staging

jobs:
  zap-api:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Fetch access token
        id: token
        run: |
          TOKEN=$(curl -s -X POST ${{ vars.STAGING_URL }}/api/auth/login \
            -H "Content-Type: application/json" \
            -d '{"username":"${{ secrets.DAST_USER }}","password":"${{ secrets.DAST_PASS }}"}' \
            | jq -r '.accessToken')
          echo "token=$TOKEN" >> $GITHUB_OUTPUT

      - name: ZAP API Scan
        uses: zaproxy/action-api-scan@v0.7.0
        with:
          target: ${{ vars.STAGING_URL }}/api/openapi.json
          format: openapi
          cmd_options: >
            -config replacer.full_list\(0\).description=auth
            -config replacer.full_list\(0\).enabled=true
            -config replacer.full_list\(0\).matchtype=REQ_HEADER
            -config replacer.full_list\(0\).matchstr=Authorization
            -config replacer.full_list\(0\).regex=false
            -config replacer.full_list\(0\).replacement=Bearer ${{ steps.token.outputs.token }}
```

### Burp Suite Enterprise — Scheduled Scanning

```java
// Burp Enterprise REST client for CI integration
@Component
public class BurpEnterpriseClient {
    private final WebClient client;

    public BurpEnterpriseClient(@Value("${burp.url}") String baseUrl,
                                @Value("${burp.api-key}") String apiKey) {
        this.client = WebClient.builder()
            .baseUrl(baseUrl)
            .defaultHeader("Authorization", apiKey)
            .build();
    }

    public String startScan(String siteId, String scanConfigurationId) {
        return client.post()
            .uri("/api/v1.0/scans")
            .bodyValue(Map.of(
                "site_id", siteId,
                "scan_configuration_ids", List.of(scanConfigurationId),
                "schedule", Map.of("start_date", Instant.now().toString())
            ))
            .retrieve()
            .bodyToMono(String.class)
            .block();
    }

    public ScanStatus getStatus(String scanId) {
        return client.get()
            .uri("/api/v1.0/scans/{id}", scanId)
            .retrieve()
            .bodyToMono(ScanStatus.class)
            .block();
    }

    public boolean hasCriticalFindings(String scanId) {
        var status = getStatus(scanId);
        return status.issueCounts().getOrDefault("critical", 0) > 0
            || status.issueCounts().getOrDefault("high", 0) > 0;
    }
}
```

**DAST execution model**:
| Stage | Target | Tool | Auth | Frequency |
|-------|--------|------|------|-----------|
| Pre-prod | Staging | ZAP Baseline | None | Every deploy |
| Pre-prod | Staging | ZAP API Scan | Bearer token | Every deploy |
| Production | Prod (read-only) | Burp Enterprise | Session cookie | Weekly |
| Production | Prod (critical paths) | Burp Enterprise | Service account | Daily |

---

## Pattern: Supply Chain Security

**Use when**: Dependencies, build artifacts, and container images must be traceable, verifiable, and tamper-proof from source to runtime.

### SBOM Generation — Syft + CycloneDX

```yaml
# .github/workflows/supply-chain.yml
name: Supply Chain — SBOM & Sign
on:
  push:
    tags: ['v*']

jobs:
  sbom:
    runs-on: ubuntu-latest
    permissions:
      id-token: write  # for Sigstore OIDC
      contents: write
    steps:
      - uses: actions/checkout@v4

      - name: Generate SBOM (Java)
        uses: anchore/sbom-action@v0
        with:
          path: .
          format: cyclonedx-json
          output-file: sbom.cyclonedx.json

      - name: Generate SBOM (Container)
        uses: anchore/sbom-action@v0
        with:
          image: ghcr.io/myorg/myapp:${{ github.ref_name }}
          format: spdx-json
          output-file: sbom.spdx.json

      - name: Upload SBOM to release
        uses: softprops/action-gh-release@v2
        with:
          files: |
            sbom.cyclonedx.json
            sbom.spdx.json
```

```java
// Runtime SBOM validation — reject images without provenance
@Component
public class SbomVerifier {
    private final RestClient client;

    public boolean verifyProvenance(String imageUri, String expectedDigest) {
        var sbom = client.get()
            .uri("https://sbom.internal/api/v1/sbom?image={image}", imageUri)
            .retrieve()
            .body(SbomDocument.class);

        if (sbom == null || !sbom.matchesDigest(expectedDigest)) {
            throw new SupplyChainException("No SBOM or digest mismatch for " + imageUri);
        }
        return true;
    }
}
```

### Artifact Signing — Sigstore/Cosign

```yaml
# .github/workflows/sign.yml
name: Sign Artifacts
on:
  push:
    tags: ['v*']

jobs:
  sign:
    runs-on: ubuntu-latest
    permissions:
      id-token: write  # OIDC for Sigstore
      contents: read
    steps:
      - uses: actions/checkout@v4

      - name: Install Cosign
        uses: sigstore/cosign-installer@v3

      - name: Build and push image
        id: build
        run: |
          docker build -t ghcr.io/myorg/myapp:${{ github.ref_name }} .
          docker push ghcr.io/myorg/myapp:${{ github.ref_name }}
          echo "digest=$(docker inspect --format='{{index .RepoDigests 0}}' ghcr.io/myorg/myapp:${{ github.ref_name }})" >> $GITHUB_OUTPUT

      - name: Sign image with Cosign (keyless)
        run: |
          cosign sign --yes \
            ${{ steps.build.outputs.digest }}

      - name: Verify signature
        run: |
          cosign verify \
            --certificate-identity-regexp='https://github.com/myorg/myapp/.github/workflows/.*' \
            --certificate-oidc-issuer='https://token.actions.githubusercontent.com' \
            ${{ steps.build.outputs.digest }}
```

```java
// Runtime verification — Kubernetes admission controller pattern
@Component
public class CosignVerifier {
    public boolean verifyImage(String imageWithDigest) {
        var process = new ProcessBuilder(
            "cosign", "verify",
            "--certificate-identity-regexp", "https://github.com/myorg/.*",
            "--certificate-oidc-issuer", "https://token.actions.githubusercontent.com",
            imageWithDigest
        ).redirectErrorStream(true).start();

        try (var reader = new BufferedReader(new InputStreamReader(process.getInputStream()))) {
            var output = reader.lines().collect(Collectors.joining("\n"));
            return process.waitFor() == 0 && output.contains("Verified OK");
        } catch (IOException | InterruptedException e) {
            throw new SupplyChainException("Cosign verification failed", e);
        }
    }
}
```

### Dependency Update Automation — Dependabot & Renovate

```yaml
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: "maven"
    directory: "/"
    schedule:
      interval: "daily"
      time: "06:00"
      timezone: "Asia/Shanghai"
    open-pull-requests-limit: 10
    reviewers:
      - "myorg/security-team"
    labels:
      - "dependencies"
      - "security"
    ignore:
      - dependency-name: "org.springframework.boot:*"
        update-types: ["version-update:semver-major"]
    groups:
      spring-patch:
        patterns:
          - "org.springframework.*"
        update-types: ["patch"]
```

```json
// renovate.json — advanced grouping and auto-merge for patches
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["config:recommended"],
  "schedule": ["before 9am on Monday"],
  "packageRules": [
    {
      "matchUpdateTypes": ["patch"],
      "matchCurrentVersion": ">= 1.0.0",
      "automerge": true,
      "automergeType": "pr",
      "platformAutomerge": true
    },
    {
      "matchPackagePatterns": ["^org.springframework.boot"],
      "groupName": "Spring Boot ecosystem",
      "matchUpdateTypes": ["minor", "patch"]
    },
    {
      "matchPackagePatterns": ["^com.fasterxml.jackson"],
      "groupName": "Jackson libraries",
      "schedule": ["at any time"]
    }
  ],
  "vulnerabilityAlerts": {
    "enabled": true,
    "labels": ["security-critical"]
  }
}
```

**Supply chain defense layers**:
| Layer | Control | Tool |
|-------|---------|------|
| Source | Signed commits, branch protection | GPG, GitHub rulesets |
| Dependencies | Automated updates, vulnerability scanning | Dependabot, Renovate, OWASP DC |
| Build | Reproducible builds, pinned actions | Maven locked versions, commit-SHA actions |
| Artifact | SBOM generation, artifact signing | Syft, Cosign, Notary |
| Deployment | Image signature verification, admission control | Kyverno, OPA/Gatekeeper |

---

## Pattern: Secret Management

**Use when**: Applications need credentials, API keys, certificates, or encryption keys without exposing them in source code, environment files, or logs.

### HashiCorp Vault — Dynamic Secrets & Lease

```java
@Configuration
public class VaultConfig {

    @Bean
    public VaultTemplate vaultTemplate(VaultEndpoint endpoint,
                                       ClientAuthentication authentication) {
        return new VaultTemplate(endpoint, authentication);
    }

    @Bean
    public ClientAuthentication kubernetesAuth() {
        // Kubernetes auth: pod service account → Vault identity
        var properties = new KubernetesAuthenticationOptions.KubernetesAuthenticationOptionsBuilder()
            .role("myapp-role")
            .jwtSupplier(new KubernetesServiceAccountTokenFile())
            .build();
        return new KubernetesAuthentication(properties, restOperations());
    }
}

@Service
public class DatabaseCredentialService {
    private final VaultTemplate vault;

    public DatabaseCredentials rotateCredentials() {
        // Dynamic secret: Vault generates short-lived DB credentials
        var response = vault.read("database/creds/myapp-readwrite");
        var username = response.getData().get("username");
        var password = response.getData().get("password");
        var leaseDuration = response.getLeaseDuration(); // e.g., 1 hour

        return new DatabaseCredentials(username, password, leaseDuration);
    }

    @Scheduled(fixedRate = 30 * 60 * 1000) // rotate before expiry
    public void renewLease() {
        vault.doWithSession(rest -> {
            rest.postForObject("/sys/leases/renew",
                Map.of("lease_id", currentLeaseId), Map.class);
            return null;
        });
    }
}
```

```hcl
# Vault policy: myapp-policy.hcl
path "secret/data/myapp/*" {
  capabilities = ["read"]
}

path "database/creds/myapp-readwrite" {
  capabilities = ["read"]
}

path "transit/decrypt/myapp" {
  capabilities = ["update"]
}

path "transit/encrypt/myapp" {
  capabilities = ["update"]
}
```

### AWS Secrets Manager — Rotation with Lambda

```java
@Component
public class AwsSecretManagerClient {
    private final SecretsManagerClient client;

    public AwsSecretManagerClient() {
        this.client = SecretsManagerClient.builder()
            .region(Region.of(System.getenv("AWS_REGION")))
            .build();
    }

    public String getSecret(String secretName) {
        var request = GetSecretValueRequest.builder().secretId(secretName).build();
        return client.getSecretValue(request).secretString();
    }

    public DatabaseCredentials getDatabaseCredentials() {
        var json = getSecret("prod/myapp/database");
        return new ObjectMapper().readValue(json, DatabaseCredentials.class);
    }
}
```

```yaml
# AWS CloudFormation: Secret + automatic rotation
AWSTemplateFormatVersion: '2010-09-09'
Resources:
  DatabaseSecret:
    Type: AWS::SecretsManager::Secret
    Properties:
      Name: prod/myapp/database
      Description: RDS master credentials
      GenerateSecretString:
        SecretStringTemplate: '{"username": "dbadmin"}'
        GenerateStringKey: password
        PasswordLength: 32
        ExcludeCharacters: '"@/\'

  SecretRotationSchedule:
    Type: AWS::SecretsManager::RotationSchedule
    Properties:
      SecretId: !Ref DatabaseSecret
      RotationLambdaARN: !GetAtt RotationLambda.Arn
      RotationRules:
        AutomaticallyAfterDays: 30

  RotationLambda:
    Type: AWS::Lambda::Function
    Properties:
      Runtime: java21
      Handler: com.myapp.rotation.SecretRotationHandler
      Code: s3://myapp-lambda-artifacts/rotation-1.0.0.jar
      Environment:
        Variables:
          SECRETS_MANAGER_ENDPOINT: https://secretsmanager.${AWS::Region}.amazonaws.com
```

### Kubernetes External Secrets Operator (ESO)

```yaml
# ExternalSecret: syncs Vault secret into K8s Secret
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: myapp-database-credentials
  namespace: production
spec:
  refreshInterval: 1h
  secretStoreRef:
    kind: ClusterSecretStore
    name: vault-backend
  target:
    name: myapp-db-secret
    creationPolicy: Owner
    template:
      type: Opaque
      data:
        DB_HOST: "{{ .db_host }}"
        DB_USER: "{{ .db_user }}"
        DB_PASS: "{{ .db_pass }}"
  data:
    - secretKey: db_host
      remoteRef:
        key: secret/data/myapp/database
        property: host
    - secretKey: db_user
      remoteRef:
        key: secret/data/myapp/database
        property: username
    - secretKey: db_pass
      remoteRef:
        key: secret/data/myapp/database
        property: password
---
# ClusterSecretStore: Vault connection
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: vault-backend
spec:
  provider:
    vault:
      server: https://vault.internal:8200
      path: secret
      version: v2
      auth:
        kubernetes:
          mountPath: kubernetes
          role: external-secrets
          serviceAccountRef:
            name: external-secrets-sa
            namespace: external-secrets
```

```java
// Spring Boot consumes the synced K8s Secret as properties
@Configuration
public class DataSourceConfig {

    @Bean
    public DataSource dataSource(
            @Value("${DB_HOST}") String host,
            @Value("${DB_USER}") String user,
            @Value("${DB_PASS}") String pass) {
        return DataSourceBuilder.create()
            .url("jdbc:postgresql://" + host + ":5432/myapp")
            .username(user)
            .password(pass)
            .build();
    }
}
```

### Secret Management Best Practices

| Practice | Implementation | Anti-Pattern |
|----------|---------------|--------------|
| **Never commit secrets** | Pre-commit hooks (`detect-secrets`, `gitleaks`) | Hardcoded keys in `application.yml` |
| **Inject at runtime** | Vault agent, ESO, AWS Secrets Manager | `.env` files in Docker images |
| **Rotate automatically** | Vault dynamic secrets, AWS rotation Lambda | Static credentials shared across environments |
| **Scope by environment** | Separate Vault namespaces / AWS accounts | Same secret used in dev/staging/prod |
| **Audit access** | Vault audit logs, CloudTrail for Secrets Manager | No logging of who read which secret |
| **Encrypt in transit & at rest** | TLS 1.3 to Vault, envelope encryption | Plaintext secret storage in etcd |
| **Fail closed** | App crashes if secret unavailable | Default fallback to empty/insecure credentials |

---

## Quick Security Checklist

Before merging ANY code:

- [ ] All SQL uses parameterized queries or ORM named parameters?
- [ ] User input validated at boundary AND service layer?
- [ ] Authorization checked at service layer (not just controller)?
- [ ] No secrets in logs, code, or git history? (run `git log -p` to verify)
- [ ] JWT tokens have short expiry (≤ 15 min) with refresh rotation?
- [ ] Rate limiting on authentication endpoints (5 attempts/minute)?
- [ ] Error messages don't leak internal details to clients?
- [ ] TLS enforced for all external communication?
- [ ] Audit trail exists for all data mutations + sensitive reads (EXPORT)?
- [ ] CSP headers, CORS correctly configured for web endpoints?
- [ ] File uploads have size + type restrictions?
- [ ] No deserialization of untrusted data (use JSON/Protobuf)?
- [ ] Dependency versions pinned and scanned for vulnerabilities?
