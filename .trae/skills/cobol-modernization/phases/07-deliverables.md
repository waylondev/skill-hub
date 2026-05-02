# Phase 8: Deliverable Specification Generation

## Objective

Generate ALL Stage 1 deliverable specifications: Entity, Repository, Service, API, Enums, Config, VSAM formats, JCL mappings, Business Rules, Security mapping. These specs are the bridge between Stage 1 analysis and Stage 2 code generation.

## Input

- All Phase 1-7 analysis documents
- `references/cobol-to-java-mappings.md` for type mappings
- `references/golden-examples.md` for code quality standards

## Deliverables (ALL in `08-deliverables/`)

### 8.1 Entity Specification

`08-deliverables/entity-specification.md`

For each Entity, document:
- Full JPA entity class (complete code, no stubs)
- Source tracing: `// Source: [COPYBOOK.cpy], lines [N]-[M]`
- Every field with @Column annotations (name, length, precision, scale)
- @Version field for optimistic locking
- Business methods (isActive(), getAvailableCredit(), etc.)
- @PrePersist/@PreUpdate lifecycle hooks

Quality standards from [references/golden-examples.md](../references/golden-examples.md):
- `@Data @Builder @NoArgsConstructor @AllArgsConstructor`
- Constructor injection (NO field injection)
- BigDecimal precision/scale always explicit
- @Index annotations for all lookup fields
- Audit fields: created_at, updated_at, created_by, updated_by

### 8.2 Repository Specification

`08-deliverables/repository-specification.md`

For each Entity, document Spring Data JPA Repository:
- Full JpaRepository<Entity, IdType> interface (complete code)
- @Lock(PESSIMISTIC_WRITE) for Update operations
- Custom @Query methods with JPQL
- Pageable findAll methods
- SEQUENCE-based ID generation (not MAX+1)
- Native query methods for DB-specific operations
- @Modifying + @Transactional for CUD operations

### 8.3 Service Implementation Guide

`08-deliverables/service-implementation-guide.md`

For each COBOL program, document Service implementation:
- Full @Service class skeleton with @Transactional
- Method signatures matching COBOL paragraphs
- Business logic translation (BigDecimal calculations)
- Validation logic mapping (Bean Validation annotations)
- Error handling (Optional.orElseThrow, catch blocks)
- Method-level security (@PreAuthorize)
- Caching annotations (@Cacheable for reference data)

### 8.4 Enums and Constants

`08-deliverables/enums-constants.md`

Document all enums derived from 88-level conditions:
```java
// Source: [COPYBOOK.cpy], lines [N]-[M]
// Original COBOL:
//     05 ACCT-STATUS PIC X(1).
//       88 ACCT-ACTIVE   VALUE 'A'.
//       88 ACCT-INACTIVE VALUE 'I'.
//       88 ACCT-CLOSED   VALUE 'O'.

public enum AccountStatus {
    ACTIVE("A"),
    INACTIVE("I"),
    CLOSED("O");

    @Getter
    private final String code;

    AccountStatus(String code) { this.code = code; }

    public static AccountStatus fromCode(String code) {
        for (AccountStatus s : values()) {
            if (s.code.equals(code)) return s;
        }
        throw new IllegalArgumentException("Unknown code: " + code);
    }
}
```

Also document constants:
```java
public final class LoanConstants {
    private LoanConstants() {}
    // Source: program.cbl WORKING-STORAGE SECTION
    public static final BigDecimal MAX_LOAN_AMOUNT = new BigDecimal("50000.00");
    public static final BigDecimal MIN_INTEREST_RATE = new BigDecimal("0.01");
}
```

### 8.5 REST API Specification

`08-deliverables/rest-api-specification.md`

For each BMS screen, document REST endpoints:

```markdown
## [Screen Name] → REST Endpoint

| Property | Value |
|----------|-------|
| **Endpoint** | `/api/v1/[resource]/[action]` |
| **HTTP Method** | GET/POST/PUT/DELETE |
| **Auth Required** | Yes/No |
| **Role** | [role] |

### Request (for POST/PUT)
```java
// Source: BMS UNPROT fields
@Data @Builder @NoArgsConstructor @AllArgsConstructor
public class [RequestName] {
    @NotBlank private String userId;  // Source: [bms map], field [name], UNPROT
    @DecimalMin("0.01") private BigDecimal amount;  // Source: [field], UNPROT
}
```

### Response
```java
@Data @Builder @NoArgsConstructor @AllArgsConstructor
public class [ResponseName] {
    private String message;      // Source: ERROR-MSG / SUCCESS-MSG
    private List<[Record]> records;  // Source: BMS line display
}
```

### Error Responses
| HTTP Status | Condition | COBOL Equivalent | Message |
|-------------|-----------|-----------------|---------|
| 400 | Validation failed | FIELD = SPACES | "Please enter ..." |
| 401 | Unauthorized | Wrong password | "Wrong Password" |
| 404 | Record not found | NOTFND | "Record NOT found" |
| 409 | Duplicate key | DUPKEY | "Record already exists" |
```

### 8.6 Business Rules

`08-deliverables/business-rules.md`

Extract all business rules discovered during Phase 5:
1. Rule ID, description, source, trigger condition, action
2. Java implementation strategy for each rule
3. Test scenario references linking to Phase 7 test matrix

| Rule ID | Description | Source | Trigger | Action | Java Strategy |
|---------|-------------|--------|---------|--------|--------------|
| BR-001 | [rule] | [pgm]:[line] | [condition] | [action] | [implementation] |

### 8.7 Project Configuration

`08-deliverables/project-config.md`

Provide complete Spring Boot configuration:

```yaml
# application.yml
spring:
  application:
    name: [project-name]
  datasource:
    url: jdbc:postgresql://localhost:5432/[db-name]
    username: ${DB_USERNAME:app_user}
    password: ${DB_PASSWORD:}
    hikari:
      minimum-idle: 5
      maximum-pool-size: 20
      idle-timeout: 300000
  jpa:
    hibernate:
      ddl-auto: validate
    properties:
      hibernate.dialect: org.hibernate.dialect.PostgreSQLDialect
      hibernate.jdbc.batch_size: 50
    show-sql: false
  flyway:
    enabled: true
    locations: classpath:db/migration
  security:
    oauth2:
      resourceserver:
        jwt:
          issuer-uri: ${AUTH_SERVER_URL:http://localhost:8080}

server:
  port: 8080
  shutdown: graceful
  tomcat:
    threads:
      max: 200
      min-spare: 10

management:
  endpoints:
    web:
      exposure:
        include: health,info,metrics,prometheus
  metrics:
    export:
      prometheus:
        enabled: true
```

### 8.8 Risk Analysis & Migration Guide

`08-deliverables/risk-analysis-migration-guide.md`

| Risk | Likelihood | Impact | Mitigation | Owner |
|------|-----------|--------|------------|-------|
| [risk] | High/Med/Low | High/Med/Low | [strategy] | [team] |

### 8.9 Security Mapping

`08-deliverables/security-mapping.md`

Map RACF→Spring Security with JWT config, method security, password migration from plain-text→BCrypt.

### 8.10 VSAM Data Formats

`08-deliverables/vsam-data-formats.md`

Document COMP-3 hex examples and unpack patterns from [references/golden-examples.md](../references/golden-examples.md). Include round-trip verification data.

### 8.11 JCL Batch Mapping

`08-deliverables/jcl-batch-mapping.md`

Map each JCL job to a concrete Spring Batch configuration class.

### 8.12 Flyway Migration Scripts (if enabled)

`09-database-migrations/V1__initial_schema.sql` — All tables with columns  
`09-database-migrations/V2__indexes_and_constraints.sql` — PKs, FKs, unique constraints  
`09-database-migrations/V3__seed_data.sql` — Reference data, lookup tables

## Execution Steps

### Step 1: Consolidate Analysis Findings

Before generating any deliverable, read ALL Phase 1-7 documents:
1. Portfolio assessment → service naming
2. VSAM analysis → Repository names + table names
3. BMS analysis → REST endpoints + DTOs
4. COPYBOOK analysis → Entity fields + Enums
5. Program logic → Service methods
6. Architecture → Microservice boundaries
7. Test matrix → Validation test data

### Step 2: Generate Entities (from Phase 4)

For each COPYBOOK:
1. Create Entity class with ALL fields
2. Add JPA annotations (@Entity, @Table, @Column, @Id)
3. Add Lombok annotations (@Data, @Builder, etc.)
4. Add @Version for optimistic locking
5. Add business methods from Phase 5 logic findings
6. Add source references in comments

### Step 3: Generate Repositories (from Phase 2)

For each VSAM file:
1. Create Repository interface extending JpaRepository
2. Add @Lock for UPDATE operations
3. Add custom @Query methods with JPQL
4. Add Pagination support

### Step 4: Generate Service Guide (from Phase 5)

For each COBOL program:
1. Create Service class with @Service + @Transactional
2. Add constructor injection for all repositories
3. Implement business logic from COMPUTE/IF/EVALUATE analysis
4. Add @PreAuthorize for security
5. Add @Cacheable for reference data

### Step 5: Generate REST API Specs (from Phase 3)

For each BMS screen:
1. Create Request/Response DTOs
2. Define endpoint REST structure
3. Map PF keys to HTTP methods
4. Add Bean Validation to Request DTOs
5. Define error responses

### Step 6: Generate Enums (from Phase 4 88-level)

Create all enum classes from 88-level conditions.

### Step 7: Generate Configurations

Create:
- application.yml
- Security configuration classes
- Batch configuration classes

### Step 8: Export ALL Deliverables

Write all files in `08-deliverables/` directory.
Write Flyway SQL scripts in `09-database-migrations/` (if enabled).

## Quality Gate

- [ ] ALL 10+ deliverable files exist in 08-deliverables/
- [ ] All code compilable (valid Java syntax)
- [ ] All fields have source references
- [ ] Mandatory QA Checks 1-30 from references/quality-checklist.md reviewed
- [ ] Flyway scripts generated (if enabled)
- [ ] Save `_state-snapshot.json` with {'phase':8,'status':'complete'}
- [ ] Generate `_kb-reference.md` for Stage 2 context
- [ ] **STOP — wait for user confirmation to proceed to Stage 2**
