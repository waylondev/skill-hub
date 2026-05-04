# RACF → Spring Security Detailed Mapping

## Overview

This document maps IBM RACF (Resource Access Control Facility) security constructs to Spring Security equivalents for COBOL mainframe modernization projects. RACF controls access at the user, group, resource, and transaction levels on z/OS.

## RACF User → Spring Security UserDetails

### RACF User Attributes Mapping

| RACF Attribute | Description | Spring Security UserDetails / DB Field |
|---------------|-------------|----------------------------------------|
| USERID | 1-8 char user identifier | `username` (String, max 8) |
| NAME | User's full name | `fullName` (custom field) |
| PASSWORD | Encrypted password (DES/SHA-256) | `password` (BCrypt encoded) |
| OWNER | User or group that owns this profile | `owner` (String) |
| DEFAULT-GROUP | Primary group | `defaultGroup` (String) |
| REVOKE DATE | Date of revocation | `credentialsNonExpired` check |
| RESUME DATE | Resume date after revoke | `credentialsNonExpired` check |
| SPECIAL | System-wide administrative authority | `ROLE_SPECIAL` authority |
| AUDITOR | Audit all security events authority | `ROLE_AUDITOR` authority |
| OPERATIONS | Operations authority (limited admin) | `ROLE_OPERATIONS` authority |
| CLAUTH | Class authorization (e.g., USER, DATASET) | Per-class GrantedAuthorities |
| UACC | Universal Access Authority (default access) | `defaultAccessLevel` (enum) |
| LAST-ACCESS | Date/time of last access | `lastLoginDate` (LocalDateTime) |

### UserDetails Implementation

```java
package com.example.migration.security;

import java.time.LocalDateTime;
import java.util.Collection;
import java.util.Collections;
import java.util.Set;

import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;

public class RacfUserDetails implements UserDetails {

    private final String userId;
    private final String password;
    private final String fullName;
    private final String defaultGroup;
    private final boolean special;
    private final boolean auditor;
    private final boolean operations;
    private final boolean revoked;
    private final LocalDate resumeDate;
    private final RacfAccessLevel defaultAccessLevel;
    private final Set<GrantedAuthority> authorities;

    public RacfUserDetails(RacfUserEntity entity) {
        this.userId = entity.getUserId();
        this.password = entity.getPassword();
        this.fullName = entity.getFullName();
        this.defaultGroup = entity.getDefaultGroup();
        this.special = entity.isSpecial();
        this.auditor = entity.isAuditor();
        this.operations = entity.isOperations();
        this.revoked = entity.getRevokeDate() != null
            && entity.getRevokeDate().isBefore(LocalDate.now());
        this.resumeDate = entity.getResumeDate();
        this.defaultAccessLevel = entity.getDefaultAccessLevel();
        this.authorities = buildAuthorities(entity);
    }

    private Set<GrantedAuthority> buildAuthorities(RacfUserEntity entity) {
        Set<GrantedAuthority> auths = new java.util.HashSet<>();
        if (entity.isSpecial()) auths.add(new SimpleGrantedAuthority("ROLE_SPECIAL"));
        if (entity.isAuditor()) auths.add(new SimpleGrantedAuthority("ROLE_AUDITOR"));
        if (entity.isOperations()) auths.add(new SimpleGrantedAuthority("ROLE_OPERATIONS"));
        for (String clauth : entity.getClassAuthorizations()) {
            auths.add(new SimpleGrantedAuthority("CLAUTH_" + clauth));
        }
        return Collections.unmodifiableSet(auths);
    }

    @Override public String getUsername() { return userId; }
    @Override public String getPassword() { return password; }
    @Override public Collection<? extends GrantedAuthority> getAuthorities() { return authorities; }
    @Override public boolean isAccountNonExpired() { return true; }
    @Override public boolean isAccountNonLocked() { return !revoked; }
    @Override public boolean isCredentialsNonExpired() {
        return resumeDate == null || resumeDate.isBefore(LocalDate.now());
    }
    @Override public boolean isEnabled() { return !revoked; }

    public String getDefaultGroup() { return defaultGroup; }
    public boolean isSpecial() { return special; }
    public boolean isAuditor() { return auditor; }
    public boolean isOperations() { return operations; }
    public RacfAccessLevel getDefaultAccessLevel() { return defaultAccessLevel; }
}
```

### RacfUserDetailsService

```java
@Service
public class RacfUserDetailsService implements UserDetailsService {

    private final RacfUserRepository userRepository;

    public RacfUserDetailsService(RacfUserRepository userRepository) {
        this.userRepository = userRepository;
    }

    @Override
    public UserDetails loadUserByUsername(String username) throws UsernameNotFoundException {
        RacfUserEntity entity = userRepository.findByUserId(username)
            .orElseThrow(() -> new UsernameNotFoundException(
                "RACF user not found: " + username));
        return new RacfUserDetails(entity);
    }
}
```

## RACF Group → Spring Security GrantedAuthority

### RACF Group Attributes

| RACF Group Attribute | Description | Spring Security Mapping |
|---------------------|-------------|------------------------|
| GROUP NAME | 1-8 char group name | `ROLE_GROUP_<name>` |
| OWNER | Group owner | N/A (metadata) |
| SUPGROUP | Superior group | Group hierarchy via `RoleHierarchy` |
| SUBGROUP(S) | Subordinate groups | Group hierarchy |
| USERS | Members | Many-to-many join table |
| UNIVERSAL ACCESS | Default group access | Base authority level |
| GROUP-SPECIAL | Admin authority within group | `ROLE_GROUP_<name>_ADMIN` |
| GROUP-AUDIT | Audit authority within group | `ROLE_GROUP_<name>_AUDITOR` |
| GROUP-AUTHORITY | Group privilege level | Custom `GroupPrivilege` enum |

### Group-Based Role Hierarchy

```java
@Configuration
public class RacfRoleHierarchyConfig {

    @Bean
    public RoleHierarchy roleHierarchy() {
        RoleHierarchyImpl hierarchy = new RoleHierarchyImpl();
        hierarchy.setHierarchy(
            "ROLE_SPECIAL > ROLE_OPERATIONS\n" +
            "ROLE_OPERATIONS > ROLE_GROUP_ADMIN\n" +
            "ROLE_AUDITOR > ROLE_GROUP_AUDITOR\n" +
            "ROLE_GROUP_ADMIN > ROLE_GROUP_USER\n" +
            "ROLE_GROUP_AUDITOR > ROLE_USER\n" +
            "ROLE_GROUP_USER > ROLE_USER\n"
        );
        return hierarchy;
    }
}
```

### GrantedAuthority Mapping Strategy

| RACF User Type | Spring GrantedAuthority Pattern | Example |
|---------------|-------------------------------|---------|
| SPECIAL | `ROLE_SPECIAL` | Full system admin |
| AUDITOR | `ROLE_AUDITOR` | Audit log access |
| OPERATIONS | `ROLE_OPERATIONS` | Limited admin |
| CLAUTH(DATASET) | `CLAUTH_DATASET` | Dataset class auth |
| GROUP: PRODGRP | `ROLE_GROUP_PRODGRP` | Group membership |
| GROUP-SPECIAL: PRODGRP | `ROLE_GROUP_PRODGRP_ADMIN` | Group admin |
| GROUP-AUDIT: PRODGRP | `ROLE_GROUP_PRODGRP_AUDITOR` | Group auditor |

## RACF Resource Class → Spring Security Permission / ACL

### Resource Class Mapping

| RACF Class | Description | Spring Security Equivalent |
|-----------|-------------|--------------------------|
| DATASET | z/OS dataset files | `@PreAuthorize("hasPermission(#dsn, 'READ')")` |
| CICS (TCICSTRN/GCICSTRN) | CICS transactions | `@PreAuthorize("hasRole('CICS_TXN_XXXX')")` |
| TMQ (MQCMDS/MQQUEUE) | MQ Series queues/commands | `@PreAuthorize("hasPermission(#queue, 'PUT')")` |
| DB2 (DSNR) | DB2 resources | `@PreAuthorize("hasPermission(#table, 'SELECT')")` |
| FACILITY | System facilities (BPX, etc.) | Application-level feature flags |
| APPL | Application access (VTAM/CICS) | `@PreAuthorize("hasRole('APPL_XXXX')")` |
| SURROGAT | Surrogate user authority | `@PreAuthorize("hasRole('SURROGATE')")` |
| OPERCMDS | Operator commands | Admin API access only |
| UNIXPRIV | USS privileges | Linux/POSIX equivalent mappings |
| SERVER (STARTED) | Started task identity | Service account via `ClientRegistration` |

### ACL-Based Dataset Permission Model

```java
@Entity
@Table(name = "racf_resource_permissions")
public class RacfResourcePermission {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "resource_class", length = 8)
    @Enumerated(EnumType.STRING)
    private RacfResourceClass resourceClass;

    @Column(name = "resource_name", length = 44)
    private String resourceName;

    @Column(name = "user_id", length = 8)
    private String userId;

    @Column(name = "group_id", length = 8)
    private String groupId;

    @Column(name = "access_level", length = 8)
    @Enumerated(EnumType.STRING)
    private RacfAccessLevel accessLevel;

    @Column(name = "when_program", length = 8)
    private String whenProgram;

    // RACF allows conditional access: PERMIT ... WHEN(PROGRAM(pgm))
    @Column(name = "when_program_condition")
    private String whenProgramCondition;
}
```

## RACF Access Levels → Spring Security Expressions

### Access Level Mapping

| RACF Level | Numeric | Meaning | Spring Security Expression |
|-----------|---------|---------|---------------------------|
| NONE | — | No access | Deny by default |
| EXECUTE | 1 | Execute only | `hasPermission(#res, 'EXECUTE')` |
| READ | 2 | Read access | `hasPermission(#res, 'READ')` |
| UPDATE | 3 | Read + Write | `hasPermission(#res, 'WRITE')` |
| CONTROL | 4 | Read + Write + Delete + Alter attributes | `hasPermission(#res, 'ADMINISTRATION')` or `hasRole('ROLE_CONTROL')` |
| ALTER | 5 | Full control including security | `hasPermission(#res, 'ADMINISTRATION')` or `hasRole('ROLE_ALTER')` |

```java
public enum RacfAccessLevel {
    NONE(0, "NO ACCESS"),
    EXECUTE(1, "EXECUTE"),
    READ(2, "READ"),
    UPDATE(3, "UPDATE"),
    CONTROL(4, "CONTROL"),
    ALTER(5, "ALTER");

    private final int numericLevel;
    private final String displayName;

    RacfAccessLevel(int numericLevel, String displayName) {
        this.numericLevel = numericLevel;
        this.displayName = displayName;
    }

    public boolean implies(RacfAccessLevel required) {
        return this.numericLevel >= required.numericLevel;
    }
}
```

### Custom PermissionEvaluator

```java
@Component
public class RacfPermissionEvaluator implements PermissionEvaluator {

    private final RacfResourcePermissionRepository permissionRepository;
    private final RacfGroupHierarchyService groupService;

    public RacfPermissionEvaluator(RacfResourcePermissionRepository permissionRepository,
                                    RacfGroupHierarchyService groupService) {
        this.permissionRepository = permissionRepository;
        this.groupService = groupService;
    }

    @Override
    public boolean hasPermission(Authentication auth, Object targetDomainObject, Object permission) {
        String userId = auth.getName();
        RacfAccessLevel required = RacfAccessLevel.valueOf(permission.toString().toUpperCase());
        String resourceName = resolveResourceName(targetDomainObject);

        return hasEffectiveAccess(userId, RacfResourceClass.DATASET, resourceName, required);
    }

    @Override
    public boolean hasPermission(Authentication auth, Serializable targetId,
                                  String targetType, Object permission) {
        String userId = auth.getName();
        RacfAccessLevel required = RacfAccessLevel.valueOf(permission.toString().toUpperCase());
        String resourceName = targetType + ":" + targetId;

        return hasEffectiveAccess(userId, resolveResourceClass(targetType), resourceName, required);
    }

    private boolean hasEffectiveAccess(String userId, RacfResourceClass resourceClass,
                                        String resourceName, RacfAccessLevel required) {
        RacfResourcePermission direct = permissionRepository
            .findByUserIdAndResourceClassAndResourceName(userId, resourceClass, resourceName)
            .orElse(null);
        if (direct != null && direct.getAccessLevel().implies(required)) return true;

        RacfUserDetails user = getRacfUser(userId);
        if (user == null || user.getDefaultGroup() == null) return false;

        RacfResourcePermission groupPerm = permissionRepository
            .findByGroupIdAndResourceClassAndResourceName(
                user.getDefaultGroup(), resourceClass, resourceName)
            .orElse(null);
        if (groupPerm != null && groupPerm.getAccessLevel().implies(required)) return true;

        if (user.getDefaultAccessLevel() != null && user.getDefaultAccessLevel().implies(required))
            return true;

        return user.isSpecial() || (user.isOperations() && required.numericLevel <= RacfAccessLevel.CONTROL.numericLevel);
    }

    private RacfUserDetails getRacfUser(String userId) {
        try {
            SecurityContext context = SecurityContextHolder.getContext();
            Authentication auth = context.getAuthentication();
            if (auth != null && auth.getPrincipal() instanceof RacfUserDetails) {
                return (RacfUserDetails) auth.getPrincipal();
            }
        } catch (Exception ignored) {}
        return null;
    }

    private String resolveResourceName(Object target) {
        if (target instanceof String) return (String) target;
        return target != null ? target.toString() : "";
    }

    private RacfResourceClass resolveResourceClass(String type) {
        try {
            return RacfResourceClass.valueOf(type.toUpperCase());
        } catch (IllegalArgumentException e) {
            return RacfResourceClass.DATASET;
        }
    }
}
```

## Transaction-Level Security → @PreAuthorize

### CICS Transaction → Spring Method Security

| RACF CICS XTRAN/TCICSTRN | Spring Expression |
|-------------------------|-------------------|
| Allow transaction XXXX | `@PreAuthorize("hasRole('TXN_XXXX')")` |
| Allow XXXX for group Y | `@PreAuthorize("hasRole('GROUP_GRPY') and hasRole('TXN_XXXX')")` |

```java
@Service
public class CicsTransactionGateway {

    @PreAuthorize("hasRole('TXN_ACCT')")
    public AccountResponse executeAcctTransaction(AccountRequest request) {
        // Equivalent to CICS transaction ACCT with RACF XTRAN=ACCT
    }

    @PreAuthorize("hasRole('TXN_UPDT') and hasRole('ROLE_TELLER')")
    public UpdateResponse executeUpdateTransaction(UpdateRequest request) {
        // Equivalent to CICS transaction UPDT, restricted to TELLER role
    }

    @PreAuthorize("hasAnyRole('ROLE_SPECIAL', 'ROLE_OPERATIONS')")
    public AdminResponse executeAdminTransaction(AdminRequest request) {
        // Equivalent to OPERCMDS-level access
    }
}
```

## Field-Level Security → @PostFilter / @PreFilter

### Field-Level Access Control

Equivalent to RACF field-level security (SEGMENT/SUBSYS controls):

```java
@Service
public class CustomerService {

    @PostFilter("hasPermission(filterObject, 'READ')")
    public List<CustomerRecord> getAllCustomers() {
        return customerRepository.findAll();
    }

    @PostFilter("hasRole('ROLE_AUDITOR') or hasPermission(filterObject, 'READ')")
    public List<AuditRecord> getAuditLogs() {
        return auditRepository.findAll();
    }

    @PreFilter("hasPermission(filterObject, 'WRITE')")
    public void batchUpdateCustomers(List<CustomerRecord> records) {
        records.forEach(this::update);
    }
}
```

### Masking Sensitive Fields

```java
@Component
public class RacfFieldMaskingService {

    @PreAuthorize("hasAnyRole('ROLE_SPECIAL', 'ROLE_AUDITOR')")
    public CustomerFullView getFullView(Long customerId) {
        // Returns all fields including sensitive SSN, salary, etc.
    }

    @PreAuthorize("hasRole('ROLE_USER')")
    public CustomerMaskedView getMaskedView(Long customerId) {
        // Returns only non-sensitive fields (name masked, SSN hidden)
    }
}
```

## SecurityFilterChain Configuration with RACF-Equivalent Rules

```java
@Configuration
@EnableWebSecurity
@EnableMethodSecurity(prePostEnabled = true)
public class RacfSecurityConfig {

    private final RacfUserDetailsService userDetailsService;

    public RacfSecurityConfig(RacfUserDetailsService userDetailsService) {
        this.userDetailsService = userDetailsService;
    }

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        http
            .authorizeHttpRequests(auth -> auth
                // DATASET-equivalent: API path permissions
                .requestMatchers("/api/public/**").permitAll()
                .requestMatchers("/api/admin/**")
                    .hasAnyRole("SPECIAL", "OPERATIONS")
                .requestMatchers("/api/dataset/protected/**")
                    .hasAnyAuthority("CLAUTH_DATASET")
                .requestMatchers("/api/audit/**")
                    .hasAnyRole("AUDITOR", "SPECIAL")
                // CICS-equivalent: Transaction-based access
                .requestMatchers(HttpMethod.POST, "/api/txn/acct/**")
                    .hasAuthority("TXN_ACCT")
                .requestMatchers(HttpMethod.POST, "/api/txn/updt/**")
                    .hasAuthority("TXN_UPDT")
                // MQ-equivalent: Queue operation permissions
                .requestMatchers("/api/mq/send/**")
                    .hasPermission("#queueName", "PUT")
                .requestMatchers("/api/mq/receive/**")
                    .hasPermission("#queueName", "GET")
                // DB2-equivalent: Table operation permissions
                .requestMatchers(HttpMethod.GET, "/api/db2/query/**")
                    .hasPermission("#tableName", "SELECT")
                .requestMatchers(HttpMethod.POST, "/api/db2/insert/**")
                    .hasPermission("#tableName", "INSERT")
                .requestMatchers(HttpMethod.DELETE, "/api/db2/delete/**")
                    .hasPermission("#tableName", "DELETE")
                // Default: Authenticated access
                .anyRequest().authenticated()
            )
            .userDetailsService(userDetailsService)
            .formLogin(form -> form
                .loginPage("/login")
                .defaultSuccessUrl("/home", true)
                .failureHandler(new RacfLoginFailureHandler())
            )
            .logout(logout -> logout
                .logoutSuccessUrl("/login?logout")
                .invalidateHttpSession(true)
            )
            .sessionManagement(session -> session
                .sessionCreationPolicy(SessionCreationPolicy.IF_REQUIRED)
                .maximumSessions(1)
                .maxSessionsPreventsLogin(false)
            )
            .csrf(CsrfConfigurer::disable);

        return http.build();
    }

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }
}
```

## RACF PERMIT/DENY Logic → DecisionManager

### Permit Mapping

| RACF Command | Description | Spring Equivalent |
|-------------|-------------|------------------|
| `PERMIT resource CLASS(class) ID(user) ACCESS(level)` | Grant access | Save `RacfResourcePermission` with userId |
| `PERMIT resource CLASS(class) ID(group) ACCESS(level)` | Grant group access | Save with groupId |
| `PERMIT resource CLASS(class) ID(*) ACCESS(level)` | Grant universal access | Universal access via UACC |
| `PERMIT ... WHEN(PROGRAM(pgm))` | Conditional grant | Custom `AccessDecisionVoter` |

### AffirmativeBased Decision Manager

```java
@Bean
public AccessDecisionManager accessDecisionManager() {
    List<AccessDecisionVoter<?>> voters = Arrays.asList(
        new RacfWhenProgramVoter(),
        new RacfAccessLevelVoter(),
        new RoleVoter(),
        new AuthenticatedVoter()
    );
    return new AffirmativeBased(voters);
}

public class RacfWhenProgramVoter implements AccessDecisionVoter<Object> {

    @Override
    public int vote(Authentication authentication, Object object,
                    Collection<ConfigAttribute> attributes) {
        String callerProgram = SecurityContextHolder.getContext()
            .getAuthentication().getDetails() != null
            ? SecurityContextHolder.getContext().getAuthentication()
                .getDetails().toString()
            : null;

        if (callerProgram != null && attributes.stream()
                .anyMatch(attr -> attr.getAttribute().equals("PROGRAM_" + callerProgram))) {
            return ACCESS_GRANTED;
        }
        return ACCESS_ABSTAIN;
    }

    @Override public boolean supports(ConfigAttribute attribute) { return true; }
    @Override public boolean supports(Class<?> clazz) { return true; }
}
```

## Complete Security Entity Model

```java
@Entity
@Table(name = "racf_users")
public class RacfUserEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "user_id", length = 8, unique = true, nullable = false)
    private String userId;

    @Column(name = "full_name", length = 50)
    private String fullName;

    @Column(name = "password")
    private String password;

    @Column(name = "default_group", length = 8)
    private String defaultGroup;

    @Column(name = "owner", length = 8)
    private String owner;

    private boolean special;
    private boolean auditor;
    private boolean operations;

    @Column(name = "revoke_date")
    private LocalDate revokeDate;

    @Column(name = "resume_date")
    private LocalDate resumeDate;

    @Column(name = "last_access")
    private LocalDateTime lastAccess;

    @Enumerated(EnumType.STRING)
    @Column(name = "default_access_level", length = 8)
    private RacfAccessLevel defaultAccessLevel;

    @ElementCollection
    @CollectionTable(name = "racf_user_clauth",
        joinColumns = @JoinColumn(name = "user_id"))
    @Column(name = "class_auth", length = 8)
    private Set<String> classAuthorizations = new HashSet<>();

    @ManyToMany(fetch = FetchType.EAGER)
    @JoinTable(name = "racf_user_groups",
        joinColumns = @JoinColumn(name = "user_id"),
        inverseJoinColumns = @JoinColumn(name = "group_id"))
    private Set<RacfGroupEntity> groups = new HashSet<>();

    @ElementCollection
    @CollectionTable(name = "racf_user_segments",
        joinColumns = @JoinColumn(name = "user_id"))
    @Column(name = "segment", length = 8)
    private Set<String> segments = new HashSet<>();
}
```

## RACF Audit Log → Spring Security Events

```java
@Component
public class RacfAuditEventListener {

    private final AuditLogRepository auditLogRepository;

    public RacfAuditEventListener(AuditLogRepository auditLogRepository) {
        this.auditLogRepository = auditLogRepository;
    }

    @EventListener
    public void onAuthenticationSuccess(AuthenticationSuccessEvent event) {
        AuditEntry entry = AuditEntry.builder()
            .userId(event.getAuthentication().getName())
            .eventType("AUTH_SUCCESS")
            .timestamp(LocalDateTime.now())
            .build();
        auditLogRepository.save(entry);
    }

    @EventListener
    public void onAuthorizationFailure(AuthorizationDeniedEvent event) {
        AuditEntry entry = AuditEntry.builder()
            .userId(SecurityContextHolder.getContext().getAuthentication() != null
                ? SecurityContextHolder.getContext().getAuthentication().getName()
                : "ANONYMOUS")
            .eventType("AUTHZ_DENIED")
            .resource(event.getAuthorizationDecision() != null
                ? event.getAuthorizationDecision().toString() : "UNKNOWN")
            .timestamp(LocalDateTime.now())
            .build();
        auditLogRepository.save(entry);
    }

    @EventListener
    public void onAuthenticationFailure(AuthenticationFailureBadCredentialsEvent event) {
        AuditEntry entry = AuditEntry.builder()
            .userId((String) event.getAuthentication().getPrincipal())
            .eventType("AUTH_FAILURE")
            .timestamp(LocalDateTime.now())
            .build();
        auditLogRepository.save(entry);
    }
}
```

## Quick Reference: RACF → Spring Mapping Summary

| RACF Construct | Spring Security Equivalent |
|---------------|--------------------------|
| USER profile → | `UserDetails` implementation |
| GROUP profile → | `GrantedAuthority` + `RoleHierarchy` |
| DATASET class → | `@PreAuthorize("hasPermission(#dsn, 'READ')")` |
| CICS TCICSTRN → | `@PreAuthorize("hasRole('TXN_XXXX')")` |
| MQQUEUE → | `@PreAuthorize("hasPermission(#queue, 'PUT')")` |
| DSNR (DB2) → | `@PreAuthorize("hasPermission(#table, 'SELECT')")` |
| READ access → | `hasPermission(#res, 'READ')` |
| UPDATE access → | `hasPermission(#res, 'WRITE')` |
| CONTROL access → | `hasRole('ROLE_CONTROL')` |
| ALTER access → | `hasRole('ROLE_ALTER')` |
| SPECIAL attr → | `ROLE_SPECIAL` |
| AUDITOR attr → | `ROLE_AUDITOR` |
| OPERATIONS attr → | `ROLE_OPERATIONS` |
| PERMIT command → | `permissionRepository.save(perm)` |
| DENY logic → | Default-deny via `AffirmativeBased` voters |
| WHEN(PROGRAM) → | Custom `AccessDecisionVoter` |
| REVOKE/RESUME → | `isAccountNonLocked()` / `isCredentialsNonExpired()` |
| UACC → | `RacfUserDetails.getDefaultAccessLevel()` |
| SEGMENT fields → | `@PostAuthorize` / `@PostFilter` |
| SMF audit → | Spring `@EventListener` + Audit DB |

## Integration Notes

- Referenced by: quality-checklist.md check 30 (Security Coverage), SKILL.md Phase 13 (Security Audit), SKILL.md Stage 3 Phase 10e (Security deliverable)
- Last reviewed: 2026-05-04
