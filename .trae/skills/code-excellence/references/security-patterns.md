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
