# Phase 8: Deliverable Specification Generation

## Objective

Generate ALL Stage 2 deliverable specifications. Every deliverable must be **complete, compilable Java code** — no stubs, no pseudocode, no placeholders. These specs are the direct input for Stage 2 code generation and must be precise enough that a different AI session can generate working code from them without reading the original COBOL source.

## Input

- All Phase 1-7 analysis documents (read summaries from `_kb-reference.md`)
- `references/cobol-to-java-mappings.md` for type mappings
- `references/golden-examples.md` for code quality standards

## Deliverable Precision Standard

Every deliverable file is evaluated against the following criteria. **If any item is incomplete, regenerate the entire deliverable.**

| Deliverable | Precision Requirement |
|-------------|----------------------|
| Entity Specification | Full class code with ALL fields, annotations, business methods, `@Version`, `@PrePersist` |
| Repository Specification | Full interface code with ALL methods, `@Lock`, `@Query`, `Pageable`, `@Modifying` |
| Service Implementation | Full class code with ALL methods, constructor injection, `@Transactional`, validation logic |
| DTO Specification | **NEW** — Full Request/Response classes with `@Valid`, Bean Validation, source mapping |
| Exception Handling | **NEW** — Complete exception hierarchy + GlobalExceptionHandler with all mappings |
| REST API Specification | Complete OpenAPI 3.0 spec or full Controller code with all endpoints, request/response types |
| Enum/Constants | Full enum classes with `fromCode()` factory methods |
| JCL Batch Mapping | Complete Spring Batch `@Configuration` class with Job, Steps, Reader, Processor, Writer beans |
| Business Rules | Rule table with Java implementation code for each rule |
| Security Mapping | Complete `SecurityFilterChain` bean + JWT filter code + password migration strategy |
| OpenAPI Spec | **NEW** — OpenAPI 3.0 YAML for all endpoints |

## Deliverables

### 8.1 Entity Specification

`08-deliverables/entity-specification.md`

For each Entity, generate **complete Java class code**:

```java
// Source: [COPYBOOK.cpy], lines [N]-[M]
// VSAM File: [filename], key: [field], RECLN=[N]
@Entity
@Table(name = "[table_name]", indexes = {
    @Index(name = "idx_[name]", columnList = "[columns]")
})
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class [EntityName] {

    @Id
    @Column(name = "[col]", length = [N], nullable = false)
    private [Type] [field];

    @Column(name = "[col]", length = [N])
    private [Type] [field];

    @Version
    private Long version;

    // Lifecycle hooks
    @PrePersist
    protected void onCreate() {
        this.createdAt = LocalDateTime.now();
    }

    // Business methods
    public boolean isActive() {
        return "A".equals(this.[statusField]);
    }
}
```

Requirements:
- **Every field** from the COPYBOOK must have a corresponding Java field
- BigDecimal precision/scale ALWAYS explicit
- `@Version` ALWAYS present for entities with update operations
- Audit fields (`createdAt`, `updatedAt`, `createdBy`, `updatedBy`) ALWAYS added
- Source comment on EVERY class and field
- `@Index` for every lookup field

### 8.2 Repository Specification

`08-deliverables/repository-specification.md`

For each Entity, generate **complete Java interface code**:

```java
// Source: [VSAM file], accessed by [program.cbl]
public interface [EntityName]Repository extends JpaRepository<[EntityName], [IdType]> {

    // Source: [program.cbl], paragraph [name], line [N]
    // CICS: READ [FILE] (key-based lookup)
    Optional<[EntityName]> findById([IdType] id);

    // Source: [program.cbl], paragraph [name], line [N]
    // CICS: READ UPDATE [FILE] (pessimistic lock for update)
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT e FROM [EntityName] e WHERE e.[field] = :id")
    Optional<[EntityName]> findByIdForUpdate(@Param("id") [IdType] id);

    // Source: [program.cbl], paragraph [name], line [N]
    // CICS: READNEXT (browse with key >= start)
    @Query("SELECT e FROM [EntityName] e WHERE e.[field] > :lastId ORDER BY e.[field] ASC")
    List<[EntityName]> findAfter(@Param("lastId") [IdType] lastId, Pageable pageable);

    // Source: [program.cbl], paragraph [name], line [N]
    // CICS: READPREV (browse with key < start)
    @Query("SELECT e FROM [EntityName] e WHERE e.[field] < :firstId ORDER BY e.[field] DESC")
    List<[EntityName]> findBefore(@Param("firstId") [IdType] firstId, Pageable pageable);

    // Source: [program.cbl], paragraph [name], line [N]
    List<[EntityName]> findBy[RelatedField]([Type] value);
}
```

Requirements:
- Every VSAM file access from Phase 5 must have a corresponding Repository method
- `@Lock(PESSIMISTIC_WRITE)` for ALL update operations (CICS READ UPDATE)
- Cursor-based pagination methods (`findAfter`, `findBefore`) for ALL browse operations (CICS READNEXT/READPREV)
- SEQUENCE-based ID generation (not MAX+1)

### 8.3 DTO Specification (NEW — Previously Missing)

`08-deliverables/dto-specification.md`

For EACH BMS map from Phase 3, generate **complete Request and Response DTO classes**:

```java
// Source: [mapset].bms → [mapname]
// Program: [program.cbl]
// Screen: [purpose]
// BMS UNPROT fields → Request DTO

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class [ScreenName]Request {

    // Source: [field]I, BMS UNPROT, X(08), row [N], col [M]
    // COBOL validation: IF [field]I = SPACES → "Please enter ..."
    @NotBlank(message = "Please enter ...")
    @Size(max = 8)
    private String [javaFieldName];

    // Source: [field]I, BMS UNPROT, PIC S9(09)V99
    @NotNull
    @DecimalMin("0.01")
    private BigDecimal [javaFieldName];
}

// PROT/BRIGHT fields → Response DTO

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class [ScreenName]Response {

    // Source: [field]O, BMS PROT, X(80)
    private String errorMessage;

    // Source: [field]O, BMS PROT, X(40) — from [copybook]
    private String title;

    // Source: list display — paginated records
    private List<[RecordDto]> items;

    // Source: CDEMO-CT00-PAGE-NUM (CommArea field)
    private Integer pageNum;

    // Source: CDEMO-CT00-NEXT-PAGE-FLG (CommArea field)
    private Boolean hasNextPage;

    // Source: CDEMO-CT00-TRNID-FIRST (CommArea field)
    private String firstCursorId;

    // Source: CDEMO-CT00-TRNID-LAST (CommArea field)
    private String lastCursorId;
}

// List item DTO (for paginated screens)

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class [RecordDto] {

    // Source: [field]01I, from TRAN-RECORD TRAN-ID
    private String id;

    // Source: [field]01I, from TRAN-RECORD TRAN-DESC
    private String description;

    // Source: [field]01I, from TRAN-RECORD TRAN-AMT (formatted)
    private String formattedAmount;
}
```

**Pagination DTO Pattern (for cursor-based screens like COTRN00C, COUSR00C):**

```java
// Source: [program.cbl] PROCESS-PAGE-FORWARD/BACKWARD
// CICS: STARTBR → READNEXT×10 → ENDBR (page size = 10)
// CommArea: CDEMO-CT00-PAGE-NUM, CDEMO-CT00-TRNID-FIRST, CDEMO-CT00-TRNID-LAST, CDEMO-CT00-NEXT-PAGE-FLG

@Data
public class CursorPageResponse<T> {
    private List<T> items;
    private Integer pageNum;
    private Boolean hasNextPage;
    private Boolean hasPrevPage;
    private String nextCursor;    // lastId for PF8 (forward)
    private String prevCursor;    // firstId for PF7 (backward)
}
```

Requirements:
- Every UNPROT BMS field → Request DTO field with Bean Validation
- Every PROT BMS field → Response DTO field
- Pagination screens → CursorPageResponse with hasNext/hasPrev/cursor fields
- Source comment on EVERY field referencing BMS map and line
- Field name mapping rule documented: `[BMS_NAME]I → [javaFieldName]`

### 8.4 Service Implementation Guide

`08-deliverables/service-implementation-guide.md`

For EACH COBOL program, generate **complete Service class code**:

```java
// Source: [program.cbl], PROCEDURE DIVISION
// Program Type: [CICS Online / Batch]
// Function: [purpose from program header]

@Service
@RequiredArgsConstructor
@Slf4j
public class [ProgramName]Service {

    private final [Entity]Repository [entityRepo];
    private final [Entity2]Repository [entity2Repo];

    // Source: MAIN-PARA, lines [N]-[M]
    // CICS: EIBCALEN=0 (initial) / DFHENTER (process) / DFHPF3 (return) / DFHPF7-8 (page)
    @Transactional(readOnly = true)
    public [ResponseType] handle([RequestType] request, [ContextType] context) {
        // EIBCALEN=0 equivalent: return blank form
        if (context.isInitialRequest()) {
            return [ResponseType].builder()
                .title("[Screen Title]")
                .build();
        }

        // ENTER key: process request
        if (context.isEnterKey()) {
            return processEnterKey(request, context);
        }

        // PF3: return to parent
        if (context.isPf3Key()) {
            throw new ReturnToParentException(context.getParentProgram());
        }

        // PF7: page backward
        if (context.isPf7Key()) {
            return processPageBackward(request, context);
        }

        // PF8: page forward
        if (context.isPf8Key()) {
            return processPageForward(request, context);
        }

        throw new InvalidActionException("Invalid key pressed");
    }

    // Source: PROCESS-ENTER-KEY, lines [N]-[M]
    // Logic: [1-2 sentences from Phase 5 analysis]
    private [ResponseType] processEnterKey([RequestType] request, [ContextType] context) {
        // Validation rules from Phase 5:
        // Rule 1: IF [field] = SPACES → error (source: line [N])
        // Rule 2: IF [field] NOT NUMERIC → error (source: line [M])

        // File I/O from Phase 5:
        // READ [FILE] by [key] → (source: line [N])
        [Entity] entity = [entityRepo].findById(request.[field]())
            .orElseThrow(() -> new NotFoundException("[Entity] not found"));

        // Business logic from Phase 5:
        // [COMPUTE formula / IF condition / state transition]

        return [ResponseType].builder()
            .message("Success")
            .data([mappedData])
            .build();
    }

    // Source: PROCESS-PAGE-FORWARD, lines [N]-[M]
    // CICS: STARTBR → READNEXT × [pageSize] → ENDBR
    private [ResponseType] processPageForward([RequestType] request, [ContextType] context) {
        String startKey = request.cursor() != null
            ? request.cursor()
            : lowestKey();

        List<[Entity]> items = [entityRepo].findAfter(startKey,
            PageRequest.ofSize([pageSize] + 1));

        boolean hasNext = items.size() > [pageSize];
        if (hasNext) {
            items = items.subList(0, [pageSize]);
        }

        String nextCursor = hasNext
            ? items.get(items.size() - 1).[getId]()
            : null;

        return [ResponseType].builder()
            .items(mapToDto(items))
            .pageNum(context.pageNum() + 1)
            .hasNextPage(hasNext)
            .nextCursor(nextCursor)
            .build();
    }
}
```

Requirements:
- **Constructor injection ONLY** (no field injection)
- Every COBOL paragraph from Phase 5 → at least one Service method
- Business logic from Phase 5 MUST be translated to actual Java code (not comments)
- Validation from Phase 5 → explicit if-checks with exception throwing
- `@Transactional` on write methods, `@Transactional(readOnly = true)` on read methods
- `@PreAuthorize` for admin-only methods
- Source comment on EVERY method referencing COBOL program and line range

### 8.5 Exception Handling Specification (NEW — Previously Missing)

`08-deliverables/exception-handling.md`

#### Exception Hierarchy

```java
// Base exception — all business exceptions extend this
public abstract class CardDemoException extends RuntimeException {
    private final String errorCode;
    private final HttpStatus httpStatus;

    protected CardDemoException(String errorCode, HttpStatus httpStatus, String message) {
        super(message);
        this.errorCode = errorCode;
        this.httpStatus = httpStatus;
    }

    public String getErrorCode() { return errorCode; }
    public HttpStatus getHttpStatus() { return httpStatus; }
}

// COBOL RESP=13 (NOTFND) → 404
public class NotFoundException extends CardDemoException {
    public NotFoundException(String entityType, String id) {
        super("NOT_FOUND", HttpStatus.NOT_FOUND,
            entityType + " not found: " + id);
    }
}

// COBOL RESP=12 (DUPKEY) → 409
public class DuplicateKeyException extends CardDemoException {
    public DuplicateKeyException(String entityType, String key) {
        super("DUPLICATE_KEY", HttpStatus.CONFLICT,
            entityType + " already exists with key: " + key);
    }
}

// CICS lock conflict (RESP=106 NOSTG) → 409
public class ConcurrentModificationException extends CardDemoException {
    public ConcurrentModificationException(String message) {
        super("CONCURRENT_MODIFICATION", HttpStatus.CONFLICT, message);
    }
}

// Validation failure → 400
public class ValidationException extends CardDemoException {
    private final List<FieldError> fieldErrors;

    public ValidationException(String message, List<FieldError> errors) {
        super("VALIDATION_ERROR", HttpStatus.BAD_REQUEST, message);
        this.fieldErrors = errors;
    }
}

// PF3 return to parent (not an error, control flow)
public class ReturnToParentException extends CardDemoException {
    private final String parentProgram;

    public ReturnToParentException(String parentProgram) {
        super("RETURN", HttpStatus.OK, "Return to " + parentProgram);
        this.parentProgram = parentProgram;
    }
}

// Invalid PF key → 400
public class InvalidActionException extends CardDemoException {
    public InvalidActionException(String message) {
        super("INVALID_ACTION", HttpStatus.BAD_REQUEST, message);
    }
}
```

#### GlobalExceptionHandler

```java
@RestControllerAdvice
@Slf4j
public class GlobalExceptionHandler {

    // Source: COBOL RESP=13 (NOTFND) handling in [programs]
    @ExceptionHandler(NotFoundException.class)
    public ResponseEntity<ErrorResponse> handleNotFound(NotFoundException ex) {
        log.warn("Not found: {}", ex.getMessage());
        return ResponseEntity.status(ex.getHttpStatus())
            .body(ErrorResponse.builder()
                .errorCode(ex.getErrorCode())
                .message(ex.getMessage())
                .timestamp(LocalDateTime.now())
                .build());
    }

    // Source: COBOL RESP=12 (DUPKEY) handling in [programs]
    @ExceptionHandler(DuplicateKeyException.class)
    public ResponseEntity<ErrorResponse> handleDuplicate(DuplicateKeyException ex) {
        log.warn("Duplicate: {}", ex.getMessage());
        return ResponseEntity.status(ex.getHttpStatus())
            .body(ErrorResponse.builder()
                .errorCode(ex.getErrorCode())
                .message(ex.getMessage())
                .timestamp(LocalDateTime.now())
                .build());
    }

    // Source: COBOL lock conflict (RESP=106) in COCRDUPC, COACTUPC
    @ExceptionHandler(ConcurrentModificationException.class)
    public ResponseEntity<ErrorResponse> handleConflict(ConcurrentModificationException ex) {
        log.warn("Concurrent modification: {}", ex.getMessage());
        return ResponseEntity.status(ex.getHttpStatus())
            .body(ErrorResponse.builder()
                .errorCode(ex.getErrorCode())
                .message(ex.getMessage())
                .timestamp(LocalDateTime.now())
                .build());
    }

    // Source: MethodArgumentNotValidException from @Valid DTOs
    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ErrorResponse> handleValidation(MethodArgumentNotValidException ex) {
        List<FieldError> errors = ex.getBindingResult().getFieldErrors().stream()
            .map(fe -> FieldError.builder()
                .field(fe.getField())
                .message(fe.getDefaultMessage())
                .build())
            .toList();

        return ResponseEntity.badRequest()
            .body(ErrorResponse.builder()
                .errorCode("VALIDATION_ERROR")
                .message("Validation failed")
                .fieldErrors(errors)
                .timestamp(LocalDateTime.now())
                .build());
    }

    // Source: COBOL "other" RESP code → unexpected system error
    @ExceptionHandler(Exception.class)
    public ResponseEntity<ErrorResponse> handleGeneral(Exception ex) {
        log.error("Unexpected error", ex);
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
            .body(ErrorResponse.builder()
                .errorCode("INTERNAL_ERROR")
                .message("An unexpected error occurred")
                .timestamp(LocalDateTime.now())
                .build());
    }
}
```

#### Error Response DTO

```java
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ErrorResponse {
    private String errorCode;
    private String message;
    private LocalDateTime timestamp;
    private List<FieldError> fieldErrors;
}

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class FieldError {
    private String field;
    private String message;
}
```

#### COBOL RESP → Exception → HTTP Status Mapping

| COBOL RESP | Condition | Programs | Exception | HTTP Status |
|-----------|----------|----------|----------|------------|
| 0 (NORMAL) | Success | ALL | — | 200/201 |
| 13 (NOTFND) | Record not found | COSGN00C, COACTVWC, COCRDSLC | NotFoundException | 404 |
| 12 (DUPKEY) | Duplicate on WRITE | COUSR02C, COCRDUPC | DuplicateKeyException | 409 |
| 106 (NOSTG) | Lock conflict on READ UPDATE | COCRDUPC, COACTUPC | ConcurrentModificationException | 409 |
| 8 (ENDFILE) | End of browse | COTRN00C, COUSR00C | — (end of stream) | 200 (with hasNext=false) |
| Other | Unexpected error | ALL | InternalServerError | 500 |
| Validation IF | Field = SPACES / NOT NUMERIC | ALL | MethodArgumentNotValidException | 400 |

### 8.6 REST API Specification (Controller Code)

`08-deliverables/rest-api-specification.md`

For EACH BMS screen, generate **complete Controller class code**:

```java
// Source: [mapset].bms → [program.cbl]
@RestController
@RequestMapping("/api/v1/[resource]")
@RequiredArgsConstructor
public class [ScreenName]Controller {

    private final [ProgramName]Service service;

    // Source: [mapset].bms, SEND MAP (initial display)
    // CICS: EIBCALEN=0 → display blank screen
    @GetMapping
    public ResponseEntity<[ResponseDto]> getInitialScreen() {
        return ResponseEntity.ok(service.getInitialScreen());
    }

    // Source: [mapset].bms, RECEIVE MAP → PROCESS ENTER
    // CICS: EIBAID=DFHENTER → validate and process
    @PostMapping
    public ResponseEntity<[ResponseDto]> process(
            @Valid @RequestBody [RequestDto] request,
            @RequestHeader(value = "X-User-Id", required = false) String userId) {
        return ResponseEntity.ok(service.process(request, userId));
    }
}
```

Requirements:
- Every BMS map → at least one GET endpoint (initial display) and one POST endpoint (process)
- PF3 → handled by service returning redirect instruction
- PF7/PF8 → POST with cursor parameter in request body
- `@Valid` on ALL Request DTOs
- `@PreAuthorize` on admin endpoints

### 8.7 Enums and Constants

`08-deliverables/enums-constants.md`

For EACH 88-level condition set from Phase 4:

```java
// Source: [COPYBOOK.cpy], lines [N]-[M]
// Original COBOL:
//     05 [field] PIC X(01).
//       88 [CONST-1] VALUE '[val1]'.
//       88 [CONST-2] VALUE '[val2]'.

@Getter
public enum [EnumName] {
    [CONST_1]("[val1]"),
    [CONST_2]("[val2]");

    private final String code;

    [EnumName](String code) { this.code = code; }

    public static [EnumName] fromCode(String code) {
        for ([EnumName] v : values()) {
            if (v.code.equals(code)) return v;
        }
        throw new IllegalArgumentException("Unknown [EnumName] code: " + code);
    }
}
```

Also generate `Constants` classes from WORKING-STORAGE literal values:

```java
// Source: [program.cbl] WORKING-STORAGE SECTION, lines [N]-[M]
public final class [ProgramName]Constants {
    private [ProgramName]Constants() {}

    public static final String [CONST_NAME] = "[value]";
}
```

### 8.8 JCL Batch Mapping → Spring Batch Configuration

`08-deliverables/jcl-batch-mapping.md`

For EACH JCL job, generate **complete Spring Batch configuration class**:

```java
// Source: [jobname].jcl
// COBOL Program: [program.cbl]
// Schedule: [Daily/Weekly/Monthly] at [time]

@Configuration
@RequiredArgsConstructor
public class [JobName]BatchConfig {

    private final JobBuilderFactory jobBuilderFactory;
    private final StepBuilderFactory stepBuilderFactory;
    private final [Entity]Repository [entityRepo];

    @Bean
    public Job [jobName]Job() {
        return jobBuilderFactory.get("[jobName]")
            .start([step1Name]())
            .next([step2Name]())
            .build();
    }

    @Bean
    public Step [step1Name]() {
        return stepBuilderFactory.get("[step1Name]")
            .<InputRecord, OutputRecord>chunk(100)
            .reader([readerName]())
            .processor([processorName]())
            .writer([writerName]())
            .faultTolerant()
            .skipPolicy([skipPolicyName]())
            .skipLimit(1000)
            .build();
    }

    @Bean
    public FlatFileItemReader<[InputRecord]> [readerName]() {
        return new FlatFileItemReaderBuilder<[InputRecord]>()
            .name("[readerName]")
            .resource(new ClassPathResource("input/[filename].dat"))
            .fixedLength()
            .columns(new Range[]{new Range(1, 16), new Range(17, 18), ...})
            .names(new String[]{"transactionId", "typeCode", ...})
            .fieldSetMapper(new BeanWrapperFieldSetMapper<[InputRecord]>() {{
                setTargetType([InputRecord].class);
            }})
            .build();
    }

    @Bean
    public ItemProcessor<[InputRecord], [OutputRecord]> [processorName]() {
        return record -> {
            // Source: [program.cbl] processing logic
            // LOOKUP: [Entity] by [key]
            // SKIP if not found (logged to reject file)
            return [processorLogic];
        };
    }

    @Bean
    public JdbcBatchItemWriter<[OutputRecord]> [writerName](DataSource dataSource) {
        return new JdbcBatchItemWriterBuilder<[OutputRecord]>()
            .dataSource(dataSource)
            .sql("INSERT INTO [table] ([columns]) VALUES ([placeholders])")
            .beanMapped()
            .build();
    }
}
```

Requirements:
- Every JCL job → one Spring Batch Job bean
- Every JCL step → one Spring Batch Step bean
- Every COBOL file READ/WRITE in batch → ItemReader/ItemWriter
- Every skip condition from Phase 5 → SkipPolicy
- Control card values → `@Value` or `@ConfigurationProperties`

### 8.9 Business Rules

`08-deliverables/business-rules.md`

Extract ALL business rules from Phase 5:

```markdown
| Rule ID | Description | Source | Trigger | Action | Java Implementation |
|---------|-------------|--------|---------|--------|-------------------|
| BR-001 | User ID must be uppercase | COSGN00C:[line] | Login attempt | Convert to uppercase | `userId.toUpperCase()` |
| BR-002 | Card name: alpha + spaces only | COCRDUPC:[line] | Card update | Reject if contains digits | `@Pattern(regexp="^[a-zA-Z ]+$")` |
```

Each rule must link to a test case in Phase 7 test matrix.

### 8.10 Security Mapping

`08-deliverables/security-mapping.md`

Complete Spring Security configuration:

```java
@Configuration
@EnableWebSecurity
@EnableMethodSecurity
public class SecurityConfig {

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            .csrf(csrf -> csrf.disable())
            .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/api/v1/auth/login").permitAll()
                .requestMatchers("/api/v1/admin/**").hasRole("ADMIN")
                .requestMatchers("/api/v1/**").hasAnyRole("ADMIN", "USER")
                .anyRequest().authenticated()
            )
            .addFilterBefore(jwtAuthenticationFilter(), UsernamePasswordAuthenticationFilter.class);
        return http.build();
    }

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }
}
```

Password migration strategy:
- Phase 1: Accept both plain-text (COBOL) and BCrypt (new) passwords
- Phase 2: On next login, hash plain-text password to BCrypt
- Phase 3: Remove plain-text support

### 8.11 Flyway Migration Scripts

`09-database-migrations/V1__initial_schema.sql`

Generate complete DDL for all tables based on Entity specifications.

### 8.12 OpenAPI Specification (NEW)

`08-deliverables/openapi-spec.yaml`

Generate OpenAPI 3.0 YAML covering all endpoints.

## Execution Steps

### Step 1: Consolidate Analysis Findings

Read ALL Phase 1-7 documents via `_kb-reference.md`.

### Step 2: Generate Entities (from Phase 4 + Phase 2)

For each VSAM file / COPYBOOK:
1. Create Entity class with ALL fields
2. Add JPA annotations
3. Add @Version
4. Add business methods from Phase 5

### Step 3: Generate Repositories (from Phase 2 + Phase 5)

For each VSAM file:
1. Create Repository interface
2. Add @Lock for UPDATE operations
3. Add cursor-based pagination methods for browse operations

### Step 4: Generate DTOs (from Phase 3 — NEW)

For each BMS map:
1. Create Request DTO from ALL UNPROT fields
2. Create Response DTO from ALL PROT/BRIGHT fields
3. Create pagination response wrapper if screen supports PF7/PF8

### Step 5: Generate Exception Hierarchy + GlobalExceptionHandler (NEW)

1. Create exception classes for each error type from Phase 5
2. Create GlobalExceptionHandler with @ExceptionHandler for each
3. Create ErrorResponse and FieldError DTOs

### Step 6: Generate Service Implementation (from Phase 5)

For each COBOL program:
1. Create Service class with constructor injection
2. Translate ALL business logic to Java code
3. Add @Transactional, @PreAuthorize

### Step 7: Generate Controller (from Phase 3)

For each BMS screen:
1. Create Controller with GET/POST endpoints
2. Wire to Service

### Step 8: Generate Spring Batch Configuration (from Phase 5 + JCL)

For each batch program:
1. Create Job/Step configuration
2. Create ItemReader/ItemProcessor/ItemWriter

### Step 9: Generate Enum/Constants (from Phase 4)

For each 88-level set.

### Step 10: Generate Security Config (from Phase 6)

SecurityFilterChain, PasswordEncoder, JWT filter.

### Step 11: Export ALL Deliverables

Write all files in `08-deliverables/`.

## Quality Gate

- [ ] ALL 12+ deliverable files exist in 08-deliverables/
- [ ] All Entity classes compile (valid Java syntax)
- [ ] All Repository interfaces compile
- [ ] All Service classes compile
- [ ] All DTO classes compile
- [ ] All Controller classes compile
- [ ] All Exception classes compile
- [ ] All Batch configuration classes compile
- [ ] All fields have source references
- [ ] Every BMS map has Request + Response DTO
- [ ] Every COBOL program has corresponding Service class
- [ ] Every VSAM file access has corresponding Repository method
- [ ] Every validation rule has Bean Validation + exception mapping
- [ ] Mandatory QA Checks 1-30 from references/quality-checklist.md reviewed
- [ ] Cross-validation rules (SKILL.md) all pass
- [ ] Save `_state-snapshot.json` with `{'phase':8,'status':'complete'}`
- [ ] Generate `_kb-reference.md` for Stage 2 context
- [ ] **STOP — wait for user confirmation to proceed to Stage 2**
