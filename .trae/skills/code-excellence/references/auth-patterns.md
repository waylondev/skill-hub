# Authentication & Identity Patterns — Principal Architect Reference

## Purpose

Production-grade authentication and authorization patterns that every principal architect must design correctly. Extends security-patterns.md with modern identity architecture: OAuth2, OIDC, SAML, SSO, MFA, and zero-trust principles.

---

## AU-1: OAuth2 + OIDC Architecture

**Use when**: Building or integrating an authentication system. OAuth2 (authorization) + OIDC (authentication on top of OAuth2) is the modern standard.

### ❌ Wrong — Homegrown Auth, Roll-Your-Own JWT

```java
// Self-issued JWT — no standard validation, no JWKS endpoint, no revocation
// "We'll just sign with HS256 and a shared secret."
// Problem: Secret leaked = all tokens compromised. No way to revoke without rotating secret.

public class InsecureTokenService {
    private static final String SECRET = "super-secret-key-2024"; // hardcoded!

    public String issueToken(Long userId) {
        return Jwts.builder()
            .subject(userId.toString())
            .signWith(Keys.hmacShaKeyFor(SECRET.getBytes()))  // HS256, hardcoded
            .compact();
    }
}
```

### ✅ Expert Fix — OAuth2 Authorization Server + Resource Server

```yaml
# Spring Security OAuth2 — Authorization Server (Keycloak / Auth0 / Okta)
spring:
  security:
    oauth2:
      resourceserver:
        jwt:
          issuer-uri: https://auth.example.com/realms/production
          # Validates: iss, exp, nbf, signature via JWKS endpoint
```

```java
// Resource Server — validates tokens, NEVER issues them
@Configuration
@EnableWebSecurity
public class ResourceServerConfig {

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        return http
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/actuator/health").permitAll()
                .requestMatchers(HttpMethod.GET, "/api/**").hasAuthority("SCOPE_read")
                .requestMatchers(HttpMethod.POST, "/api/**").hasAuthority("SCOPE_write")
                .requestMatchers("/api/admin/**").hasRole("ADMIN")
                .anyRequest().authenticated()
            )
            .oauth2ResourceServer(oauth2 -> oauth2
                .jwt(jwt -> jwt
                    .jwtAuthenticationConverter(jwtAuthConverter())
                )
            )
            .build();
    }

    // Extract custom claims into Spring Security context
    private Converter<Jwt, AbstractAuthenticationToken> jwtAuthConverter() {
        var converter = new JwtAuthenticationConverter();
        converter.setJwtGrantedAuthoritiesConverter(jwt -> {
            var roles = jwt.getClaimAsStringList("roles");
            if (roles == null) return List.of();
            return roles.stream()
                .map(r -> new SimpleGrantedAuthority("ROLE_" + r))
                .collect(Collectors.toSet());
        });
        return converter;
    }
}
```

```java
// Service layer — secure by annotation
@Service
public class OrderService {

    @PreAuthorize("hasAuthority('SCOPE_write') and #userId == authentication.principal.id")
    public OrderRs createOrder(Long userId, CreateOrderRq req) {
        // Only the authenticated user can create their own orders
        return orderRepo.save(Order.create(userId, req));
    }

    @PreAuthorize("hasAuthority('SCOPE_read') or hasAuthority('SCOPE_write')")
    public List<OrderRs> listOrders(Long userId) {
        return orderRepo.findByUserId(userId);
    }
}
```

**OAuth2 Flow Selection:**

| Flow | Grant Type | Best For |
|------|-----------|----------|
| **Authorization Code + PKCE** | `authorization_code` | Web apps, mobile apps, SPA |
| **Client Credentials** | `client_credentials` | Service-to-service (M2M) |
| **Device Code** | `urn:ietf:params:oauth:grant-type:device_code` | TV, IoT, CLI tools |
| **JWT Bearer** | `urn:ietf:params:oauth:grant-type:jwt-bearer` | Service account impersonation |
| ~~Resource Owner Password~~ | ~~`password`~~ | **DEPRECATED** — never use |

**Expert Note**: NEVER build your own authorization server. Keycloak, Auth0, Okta, Azure AD — choose one. The complexity of OAuth2/OIDC (token formats, JWKS rotation, revocation, consent screens) is a solved problem. Building your own is the security equivalent of building your own crypto library. The Resource Server pattern (validate tokens, don't issue them) is the correct boundary for application code.

---

## AU-2: Token Lifecycle & Rotation

**Use when**: Managing JWT access tokens, refresh tokens, and API keys. Token lifecycle management prevents stale access and limits breach blast radius.

### ❌ Wrong — Long-Lived Tokens, No Rotation

```java
// Access token: 24 hours, no refresh mechanism. No revocation.
// Token stolen → attacker has 24 hours of access. No way to stop it.

String token = Jwts.builder()
    .setExpiration(new Date(System.currentTimeMillis() + 86400000))  // 24 hours
    .compact();
```

### ✅ Expert Fix — Short-Lived Access + Refresh + Rotation

```java
// Token lifecycle architecture
public record TokenPolicy(
    Duration accessTokenLifetime,      // 5-15 minutes
    Duration refreshTokenLifetime,     // 7-30 days (rotated on use)
    Duration refreshTokenAbsoluteLifetime, // 90 days (hard limit)
    int maxRefreshTokenReuse           // 1 (single use, rotate on refresh)
) {
    public static final TokenPolicy STANDARD = new TokenPolicy(
        Duration.ofMinutes(15),        // access: 15 min
        Duration.ofDays(7),            // refresh: 7 days (with rotation)
        Duration.ofDays(90),           // absolute: 90 days (re-auth required)
        1                              // single use only
    );

    public static final TokenPolicy PAYMENT = new TokenPolicy(
        Duration.ofMinutes(5),         // access: 5 min (payment = extra sensitive)
        Duration.ofHours(1),           // refresh: 1 hour
        Duration.ofDays(1),            // absolute: 24 hours
        1
    );
}
```

```java
// Refresh token rotation — detect token reuse (theft detection)
@Service
public class TokenRotationService {

    public TokenPair refresh(String refreshToken) {
        var stored = tokenRepo.findByRefreshToken(refreshToken)
            .orElseThrow(() -> new InvalidTokenException("Unknown refresh token"));

        // Theft detection: token already used ← THIS IS THE KEY
        if (stored.isUsed()) {
            // Someone is reusing a refresh token!
            // Revoke ALL tokens for this user family — attacker has a stolen token
            tokenRepo.revokeFamily(stored.familyId());
            securityAlert.send(new TokenReuseDetectedAlert(stored.userId()));
            throw new TokenReuseException("Token reuse detected — all sessions revoked");
        }

        // Mark as used (single use) + generate new refresh token (rotation)
        stored.markAsUsed();
        var newTokens = generateNewTokenPair(stored.userId(), stored.familyId());
        tokenRepo.save(newTokens.refresh());
        return newTokens;
    }
}
```

**Token Lifecycle Flow:**
```
1. User authenticates → [Access: 15min] + [Refresh: 7d, rotatable]
2. Access expires after 15 minutes → Client: no action needed yet
3. API returns 401 → Client uses Refresh token → [New Access: 15min] + [New Refresh: 7d]
   OLD Refresh token marked as USED (rotation)
4. If OLD Refresh token reused → THEFT DETECTION → revoke ALL tokens
5. After 90 days absolute → Re-authentication required
```

**Expert Note**: Refresh token rotation with reuse detection is the single most effective theft mitigation. If a refresh token is stolen and the attacker uses it, the legitimate user's next refresh will use a token that's already been consumed → theft detected → all sessions revoked. The attacker gets one use; the legitimate user loses access but is protected from ongoing compromise.

---

## AU-3: Multi-Tenancy Authorization (RBAC + ABAC)

**Use when**: SaaS applications need tenant isolation, role-based access, and fine-grained attribute-based rules.

### ❌ Wrong — Simple Role Check, No Tenant Isolation

```java
// Just check if user has "ADMIN" role. No tenant context.
// Tenant-A admin can see Tenant-B data because no tenant filter applied.

@PreAuthorize("hasRole('ADMIN')")
public List<Order> getAllOrders() {
    return orderRepo.findAll();  // Returns ALL tenants' orders!
}
```

### ✅ Expert Fix — RBAC + Tenant Scoping + ABAC for Fine-Grained

```java
// Layer 1: Tenant context (EVERY query scoped to tenant)
@AuthenticationPrincipal
public class TenantUser implements OAuth2AuthenticatedPrincipal {
    private final String tenantId;  // from JWT claim
    private final Set<String> roles;
    private final String userId;

    // Tenant scoping — enforced at repository level
    public String tenantQualifiedId() {
        return tenantId + ":" + userId;
    }
}

// Layer 2: Repository-level tenant isolation (CANNOT bypass)
@Repository
public interface OrderRepository extends JpaRepository<Order, Long> {

    @Query("SELECT o FROM Order o WHERE o.tenantId = :tenantId AND o.userId = :userId")
    List<Order> findByTenantAndUser(@Param("tenantId") String tenantId,
                                     @Param("userId") String userId);

    @Query("SELECT o FROM Order o WHERE o.tenantId = :tenantId")
    List<Order> findByTenant(@Param("tenantId") String tenantId);  // admin only, ALL tenant
}

// Layer 3: ABAC — attribute-based for fine-grained access
@Component
public class AbacPolicyEngine {

    /**
     * Policy: "A user can cancel their own order if:
     *           - order.status == PENDING AND
     *           - order.createdAt < 24 hours ago AND
     *           - user.role == CUSTOMER OR user.role == SUPPORT"
     */
    public boolean canCancelOrder(TenantUser user, Order order) {
        // Tenant boundary — HARD rule
        if (!user.tenantId().equals(order.tenantId())) {
            audit.log(new CrossTenantAccessAttempt(user, order));
            return false; // REJECT: never cross tenants
        }

        // Ownership OR support override
        boolean isOwner = user.userId().equals(order.userId());
        boolean isSupport = user.roles().contains("SUPPORT");

        if (!isOwner && !isSupport) return false;

        // Time-based constraint
        if (order.createdAt().isBefore(LocalDateTime.now().minusHours(24))) {
            return false; // too old to self-cancel
        }

        // State constraint
        return order.status() == OrderStatus.PENDING;
    }
}

// Usage
@Service
public class OrderService {
    private final AbacPolicyEngine abac;

    public void cancelOrder(TenantUser user, Long orderId) {
        var order = orderRepo.findById(orderId).orElseThrow();
        if (!abac.canCancelOrder(user, order)) {
            throw new AccessDeniedException("Cannot cancel order " + orderId);
        }
        order.cancel();
    }
}
```

**Authorization Model Comparison:**

| Model | Granularity | Complexity | Best For |
|-------|-------------|------------|----------|
| **RBAC** | Role-level | Low | Most apps: Admin/User/Viewer |
| **ABAC** | Attribute-level | Medium | Fine-grained: "cancel only if < 24h old" |
| **ReBAC** (Relationship) | Social graph | High | Social: "friend-of-friend can view" |
| **PBAC** (Policy) | Policy-level | High | Enterprise: XACML/OPA policies |

**Expert Note**: Tenant isolation is the #1 SaaS security concern. Every query MUST filter by tenant — no exceptions, no "admin override." The tenant filter at the repository level (not service level) is the correct enforcement point: it's impossible for any service code to accidentally retrieve cross-tenant data. RBAC covers 80% of use cases; ABAC covers the remaining 20% where attributes matter (time, state, amount).

---

## AU-4: SSO & Federation (SAML/OIDC)

**Use when**: Enterprise customers need Single Sign-On with their identity provider (IdP). SAML is still the enterprise standard despite OIDC's rise.

### The SSO Architectural Decision:

```
SAML 2.0:    Enterprise standard. XML, certificates, metadata exchange.
             Complex but universal. Okta/Azure AD/PingFederate all speak it.

OIDC:        Modern, simpler. JSON, JWKS, discovery endpoint.
             Growing enterprise adoption. Works for most SaaS.
             
Decision:    Support OIDC first (80% of customers). Add SAML for
             the 20% who require it (Fortune 500, gov, healthcare).
```

```java
// Spring Security — dual OIDC + SAML support
@Configuration
@EnableWebSecurity
public class FederationSecurityConfig {

    // OIDC — 1 hour to integrate
    @Bean
    @Order(1)
    public SecurityFilterChain oidcFilter(HttpSecurity http) throws Exception {
        return http
            .securityMatcher("/login/oauth2/**", "/oauth2/**")
            .oauth2Login(oauth2 -> oauth2
                .userInfoEndpoint(userInfo -> userInfo
                    .oidcUserService(oidcUserService()))
            )
            .build();
    }

    // SAML — requires metadata exchange with customer IdP
    @Bean
    @Order(2)
    public SecurityFilterChain samlFilter(HttpSecurity http) throws Exception {
        return http
            .securityMatcher("/saml2/**", "/login/saml2/**")
            .saml2Login(saml2 -> saml2
                .relyingPartyRegistrationRepository(relyingPartyRepo())
            )
            .saml2Logout()
            .build();
    }
}
```

**Federation Decision Matrix:**

| Customer Profile | Protocol | Integration Effort | 
|-----------------|----------|-------------------|
| Startup, SMB | OIDC (Google, GitHub) | 1 hour |
| Mid-market | OIDC (Okta, Azure AD) | 1 day (custom claims mapping) |
| Enterprise (Fortune 500) | SAML + OIDC | 1 week (metadata, certs, testing) |
| Government, Healthcare | SAML (mandatory) | 1 week + compliance review |

**Expert Note**: SAML is not going away. Despite its complexity, it remains the only protocol that every enterprise IdP supports with deep configurability (session lifetimes, step-up auth, forced re-auth). Budget SAML integration effort in your roadmap — enterprise deals depend on it. The architectural pattern: abstract the IdP behind a unified `IdentityProvider` interface, with SAML and OIDC as implementations.

---

## AU-5: Zero-Trust Architecture

**Use when**: Designing security for modern distributed systems. Zero-trust means: never trust, always verify. Every request, every service, every time.

### ❌ Wrong — Perimeter Security (Trust the Network)

```
"We're inside the VPC. Traffic between services doesn't need auth."
Result: Compromised CI pipeline → attacker deploys malicious container →
container has network access to all services → exfiltrates all data.
Zero network-level auth = total compromise from a single entry point.
```

### ✅ Expert Fix — Zero-Trust Service Mesh

```java
// Zero-trust principles applied to every service call:

// 1. NEVER trust network location (inside VPC ≠ trusted)
// 2. ALWAYS authenticate (mTLS or JWT)
// 3. ALWAYS authorize (scope/permission check)
// 4. ALWAYS audit (log every access decision)

@Component
public class ZeroTrustServiceClient {

    private final RestClient restClient;

    public OrderRs callOrderService(Long orderId, ServiceIdentity caller) {
        // Service identity = JWT with client_credentials grant
        var serviceToken = tokenService.issueServiceToken(caller);

        return restClient.get()
            .uri("http://order-service/internal/orders/{id}", orderId)
            .header("Authorization", "Bearer " + serviceToken)  // ALWAYS auth
            .retrieve()
            .body(OrderRs.class);

        // Every call logged: caller→callee, endpoint, result, duration
        // audit: caller_service=inventory, callee_service=orders,
        //        endpoint=GET /internal/orders/123, result=200, duration=45ms
    }
}
```

```yaml
# Istio / Linkerd — mTLS between ALL services (transparent to code)
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: production
spec:
  mtls:
    mode: STRICT  # ALL service-to-service traffic MUST use mTLS
```

**Zero-Trust Checklist:**

| Layer | Principle | Implementation |
|-------|-----------|----------------|
| **Network** | No implicit trust | mTLS everywhere (Istio/Linkerd) |
| **Identity** | Every service has identity | SPIFFE/SPIRE, service accounts |
| **AuthN** | Every call authenticated | JWT (short-lived, 5 min max) |
| **AuthZ** | Every call authorized | Scope + permission check |
| **Audit** | Every decision logged | Structured audit log |
| **Data** | Encrypt at rest + transit | TLS + encrypted volumes |

```java
// Zero-trust access decision logging — required for SOC2/ISO27001
@Component
public class AccessAuditor {

    public void logAccess(AccessDecision decision) {
        // Structured audit log — immutable, append-only, separate storage
        auditLog.info("ACCESS_DECISION: principal={}, resource={}, action={}, " +
            "result={}, reason={}, location={}, timestamp={}",
            decision.principal(), decision.resource(), decision.action(),
            decision.result(), decision.reason(), decision.networkLocation(),
            decision.timestamp());
    }
}
// NEVER log: passwords, tokens, secrets, PII in raw form
```

**Expert Note**: Zero-trust is not a product — it's an architectural principle. "Never trust, always verify" means every service call, regardless of network location, must authenticate and authorize. The service mesh (Istio/Linkerd) handles mTLS transparently; the application layer handles authorization. Together they ensure that even if an attacker compromises a container, they can only access what that container's identity is authorized to access — which should be minimal.

---

## Quick Auth Patterns Checklist

- [ ] OAuth2/OIDC via established IdP (Keycloak/Auth0/Okta) — not self-built?
- [ ] Resource Server pattern: validate tokens, never issue them?
- [ ] Access tokens ≤ 15 min lifetime, refresh tokens with rotation?
- [ ] Refresh token reuse detected → all sessions revoked (theft mitigation)?
- [ ] Every repository query scoped to tenant_id (no cross-tenant leakage)?
- [ ] ABAC for fine-grained access when RBAC insufficient?
- [ ] SSO: OIDC supported, SAML roadmap budgeted for enterprise?
- [ ] mTLS between ALL services (service mesh: Istio / Linkerd)?
- [ ] Every service call: authenticated + authorized + audited?
- [ ] Passwords/secrets/tokens NEVER logged (audit log sanitization)?
- [ ] Secret rotation automated (AWS Secrets Manager / Vault)?
- [ ] Principle of least privilege: every service identity has minimum required scopes?
