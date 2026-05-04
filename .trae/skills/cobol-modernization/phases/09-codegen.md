# Phase 9: AI Code Generation + Golden Examples

## Objective

Generate complete, production-grade Java code from Stage 1 analysis documents.AI reads analysis docs and generates compilable Java classes, following the Golden Code Examples standards.

## Input

- ALL Stage 1 analysis documents (00-07 directories)
- `_kb-reference.md` (compact knowledge base)
- `references/golden-examples.md` for quality standards
- `references/cobol-to-java-mappings.md` for type mappings

## Generation Order (CRITICAL — must follow this sequence)

1. **Enums + Constants** (simplest, dependencies of everything else)
2. **Entity classes** (Data model — from Phase 4 analysis)
3. **Repository interfaces** (Data access — from Phase 2 analysis)
4. **Service classes** (Business logic — from Phase 5 analysis)
5. **Configuration classes** (application.yml, SecurityConfig, BatchConfig)
6. **DTOs** (Request/Response — from Phase 3 BMS analysis)
7. **Controllers** (REST endpoints — from Phase 3 analysis)
8. **Flyway SQL** (Database migration scripts)

## Golden Code Standards (Mandatory)

Every generated Java class MUST meet the standards defined in [references/golden-examples.md](../references/golden-examples.md):

### Entity Golden Standard
```java
// REQUIRED annotations:
@Entity                              // JPA entity
@Table(name = "table_name", indexes = {...})  // Explicit table + indexes
@Data                                // Lombok
@Builder                             // Lombok
@NoArgsConstructor                   // Lombok (required by JPA)
@AllArgsConstructor                  // Lombok (for builder)
public class EntityName {

    // REQUIRED patterns:
    @Id @Column(name = "...", ...)   // Explicit column name
    private IdType id;                // Source: COBOL field info

    @Version                          // REQUIRED for concurrent safety
    private Long version;

    @Column(name = "...", precision = N, scale = M)
    private BigDecimal moneyField;     // ALWAYS BigDecimal for currency

    // Business methods from COBOL:
    public BigDecimal getAvailableCredit() { ... }
    public boolean isActive() { ... }
}
```

### Repository Golden Standard
```java
@Repository
public interface EntityNameRepository extends JpaRepository<EntityName, IdType> {

    @Lock(LockModeType.PESSIMISTIC_WRITE)  // REQUIRED for updates
    @Query("SELECT e FROM EntityName e WHERE e.id = :id")
    Optional<EntityName> findByIdForUpdate(@Param("id") IdType id);

    // All list operations support Pageable
    List<EntityName> findByField(String field, Pageable pageable);
}
```

### Service Golden Standard
```java
@Service
@Transactional
public class ServiceName {
    private final Repository1 repo1;  // Constructor injection ONLY
    private final Repository2 repo2;

    // Source: [program.cbl], paragraph [name]
    public ResponseType businessMethod(RequestType request) {
        // All financial calculations use BigDecimal
        // All updates use findByIdForUpdate()
        // All errors throw domain exceptions
    }
}
```

### Controller Golden Standard
```java
@RestController
@RequestMapping("/api/v1/[resource]")
@Tag(name = "[Name]", description = "[Description]")
public class ControllerName {
    private final ServiceName service;  // Constructor injection ONLY

    @PostMapping
    @Operation(summary = "...")
    public ResponseEntity<ResponseType> endpoint(@Valid @RequestBody RequestType request) {
        // Source: [program].cbl, [paragraph], PF key = ENTER
    }
}
```

## Code Generation Rules

### Rule 1: Complete Code Only — NO Stubs
```java
// ❌ FORBIDDEN:
// TODO: implement this method
return null; // placeholder
throw new UnsupportedOperationException("not implemented");

// ✅ REQUIRED:
return repository.findById(id)
    .orElseThrow(() -> new NotFoundException("Entity not found"));
```

### Rule 2: Source Traceability — Every Element
```java
// Source: COPYBOOKC.cpy, lines 123-145
// Source: programABC.cbl, paragraphs MAIN-PARA + PROCESS-DATA
@Column(name = "customer_name", length = 50)
private String customerName;
```

### Rule 3: BigDecimal Precision — ALWAYS Explicit
```java
// Source: COMP-3 S9(15)V99 → DECIMAL(17,2)
@Column(name = "balance", precision = 17, scale = 2)
private BigDecimal balance;

// Source: COMPUTE BALANCE = BALANCE - AMOUNT, programABC.cbl line 234
balance = balance.subtract(amount).setScale(2, RoundingMode.HALF_UP);
```

### Rule 4: Concurrency Safety
```java
// Source: CICS READ with UPDATE → @Lock(PESSIMISTIC_WRITE)
Account account = accountRepository.findByIdForUpdate(accountId)
    .orElseThrow(() -> new NotFoundException("Account not found"));
```

### Rule 5: ID Generation
```sql
-- Use SEQUENCE (NOT MAX+1)
CREATE SEQUENCE transaction_id_seq START WITH 1 INCREMENT BY 50;
```

```java
@GeneratedValue(strategy = GenerationType.SEQUENCE, generator = "transaction_seq")
@SequenceGenerator(name = "transaction_seq", sequenceName = "transaction_id_seq", allocationSize = 50)
private Long id;
```

## Contiguous File Processing

Process files identified in Phase 1 source inventory in contiguous batches:

```
Batch N: program1.cbl + program2.cbl + program3.cbl + ... (batch_size files)
```

Process consecutive files within the same source directory to maintain memory continuity and generate cohesive outputs.

After each batch:
1. Append generated code to the relevant source files
2. Update `_context-index.md` with processed files
3. Track token usage to optimize subsequent batches

## Large File Splitting Strategy

When a deliverable file exceeds reasonable size limits:

1. Create `filename-part-1-of-N.md`, `filename-part-2-of-N.md`, etc.
2. Each part file MUST begin with `> Part X of N — continued from part X-1`
3. Part 1 MUST contain a table of contents with links to all parts
4. NEVER truncate content — split into the exact number of parts needed

## Execution Steps

### Step 1: Read Stage 1 Context

Read `_kb-reference.md` for compact context summary.
Read analysis documents as needed for detailed implementation.

### Step 2: Generate Enums + Constants

Generate all enum classes from Phase 4 88-level analysis.

### Step 3: Generate Entities

For each COPYBOOK identified in Phase 4:
1. Generate Entity class file
2. Include ALL fields with JPA annotations
3. Include @Version
4. Include business methods from Phase 5
5. Include lifecycle hooks (@PrePersist, @PreUpdate)

### Step 4: Generate Repositories

For each VSAM file identified in Phase 2:
1. Generate Repository interface
2. Include PESSIMISTIC_WRITE lock for updates
3. Include all custom queries needed by services

### Step 5: Generate Services

For each COBOL program identified in Phase 5:
1. Generate Service class
2. Translate ALL business logic
3. Add @Transactional boundaries
4. Add @PreAuthorize security

### Step 6: Generate Controllers + DTOs

For each BMS screen identified in Phase 3:
1. Generate Request/Response DTOs
2. Generate REST Controller
3. Map PF keys to HTTP endpoints

### Step 7: Generate Configurations

Generate:
- `application.yml`
- `SecurityConfig.java`
- `BatchConfig.java` (for JCL jobs)
- `pom.xml`

### Step 8: Generate Flyway SQL

Generate:
- `V1__initial_schema.sql`
- `V2__indexes_and_constraints.sql`
- `V3__seed_data.sql`

### Step 9: Generate API Contract Tests (if full mode)

Using pact-jvm-consumer-junit5:
- Consumer contract test
- Provider contract test
- CI pipeline integration

### Step 10: Generate Performance Baseline (if full mode)

Using JMH benchmarks:
- CRUD benchmarks
- Complex business logic benchmarks
- Concurrent access benchmarks
- Stress profile commands

## Quality Gate (Human Review CP-5)

- [ ] All Java classes generated and compilable
- [ ] ALL source references present in comments
- [ ] ALL BigDecimal precision/scale correct
- [ ] @Version present on all entities with concurrent writes
- [ ] @Lock(PESSIMISTIC_WRITE) on all update operations
- [ ] Constructor injection used everywhere (NO field injection)
- [ ] No TODO/placeholder/stubs anywhere
- [ ] Flyway scripts present and versioned
- [ ] Java developer + architect invited to review CP-5
- [ ] Save `_state-snapshot.json` with {'phase':9,'status':'pending-review'}
