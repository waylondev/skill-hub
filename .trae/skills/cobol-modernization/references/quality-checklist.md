# Quality Checklist & Common Pitfalls

## Mandatory QA Checks

All checks MUST pass before delivery. If ANY fails, regenerate the deficient deliverable.

### Phase 1-2 Checks (Discovery & Data)

| # | Check | Criteria | Verify Method |
|---|-------|----------|--------------|
| 1 | File Coverage | 100% of .cbl/.cpy/.bms files analyzed | Count files vs documented |
| 2 | Field Coverage | 100% of COPYBOOK fields mapped (FILLER noted) | Compare COPYBOOK to entity fields |
| 3 | Logic Coverage | 100% of COMPUTE/IF/EVALUATE blocks documented | Compare COBOL paragraphs to Service methods |
| 4 | API Coverage | 100% of BMS Maps mapped to REST endpoints | Count .bms vs API endpoints |
| 5 | Code Completeness | No TODO/placeholder comments in any class | Grep for TODO/placeholder |
| 6 | Validation Coverage | All COBOL IF validations have Bean Validation | Compare IF to @Valid annotations |
| 7 | Enum Coverage | All 88-level conditions as enums | Compare 88 levels to enum values |
| 8 | Transaction Safety | All SYNCPOINT mapped to @Transactional | Compare SYNCPOINT to @Transactional |
| 9 | BigDecimal Usage | All S9(N)V99 fields use BigDecimal | Check entity field types |
| 10 | Relationship Complete | All FK relationships mapped | Check @ManyToOne/@OneToMany |
| 11 | Diagram Accuracy | Every diagram node → real COBOL entity | Trace each node to source |
| 12 | Diagram Syntax | All Mermaid diagrams render error-free | Verify in IDE preview |
| 13 | Lombok Usage | @Data @Builder @NoArgsConstructor @AllArgsConstructor | Check entity annotations |
| 14 | Modern Stack | Spring Boot 3.3.x + Java 21 + Jakarta EE 10 | Check pom.xml |
| 15 | Locking Strategy | UPDATE operations @Lock(PESSIMISTIC_WRITE) or @Version | Check repository methods |
| 16 | Cache Usage | Reference data uses @Cacheable | Check service methods |
| 17 | Pagination | All list operations support cursor-based pagination | Check repository signatures have findAfter/findBefore |
| 18 | COMP-3 Coverage | All COMP/COMP-3 with hex examples | Check vsam-data-formats.md |
| 19 | AIX Coverage | All VSAM AIX to DB indexes | Check vsam-aix-mapping.md |
| 20 | GDG Coverage | All GDG to partitioned jobs | Check jcl-batch-mapping.md |
| 21 | Assembler Coverage | All Assembler calls have Java replacements | Check assembler-replacement.md |
| 22 | DB2 Coverage | All EXEC SQL to JPA | Check repository specs |
| 23 | IMS Coverage | All EXEC DLI to JPA | Check sub-application analysis |
| 24 | MQ Coverage | All MQGET/MQPUT to JMS/RabbitMQ | Check sub-application analysis |
| 25 | JCL Coverage | All JCL jobs to Spring Batch | Check jcl-batch-mapping.md |
| 26 | Security Coverage | All RACF controls to Spring Security | Check security-mapping.md |
| 27 | REDEFINES Coverage | All REDEFINES have Java strategy | Check complex-copybook-guide.md |
| 28 | OCCURS Coverage | All OCCURS/ODI to Java Lists | Check complex-copybook-guide.md |
| 29 | Flyway Scripts | All DB migrations versioned | Check V*.sql exist |
| 30 | Code Coverage | Critical paths >= 80% coverage | Check JaCoCo reports |

### NEW Phase 3-7 Checks (BMS, Logic, Architecture, Testing)

| # | Check | Criteria | Verify Method |
|---|-------|----------|--------------|
| 31 | BMS Field Completeness | EVERY BMS map has ≥ 8 analysis sections (ASCII layout, field inventory, PF keys, input mapping, output mapping, commarea, business rules, pagination if applicable) | Count sections per map in bms-map-analysis.md |
| 32 | BMS-Program Linkage | EVERY .bms file linked to at least one .cbl program's Screen I/O section | Cross-reference BMS inventory with Phase 5 Screen I/O tables |
| 33 | Program Completeness | EVERY .cbl program has ALL 12 sections: Paragraph Inventory, Branch Map, File I/O, Screen I/O, Validation Rules, Computation Formulas, State Machine (if applicable), Variable Usage, CommArea, Error Handling, Java Method Signatures | Count sections per program in program-logic-analysis.md |
| 34 | Branch Exhaustiveness | EVERY IF/EVALUATE branch in every program documented with source line | Grep IF/EVALUATE in source, count vs Branch Map entries |
| 35 | File I/O Completeness | EVERY SELECT/ASSIGN/EXEC CICS READ/WRITE/STARTBR has corresponding Repository method | Cross-reference Phase 5 File I/O tables with Phase 8 Repository specs |
| 36 | PF Key Completeness | EVERY PF key used in a program is documented in both Phase 3 (screen) and Phase 5 (logic) | Cross-reference PF key tables across phases |
| 37 | CommArea Consistency | CommArea fields in Phase 5 match COCOM01Y definition from Phase 4 | Compare field names, PIC, lengths |
| 38 | Architecture-Program Consistency | Every COBOL program is assigned to exactly one microservice in Phase 6 | Count programs in Phase 1 vs services in Phase 6 |
| 39 | Test-Program Coverage | At least 3 test cases exist for every COBOL program in Phase 5 | Count test cases per program in Phase 7 |
| 40 | Golden Test Baseline | Golden test input/output defined for all CRUD + batch operations | Verify fixture table completeness |

### NEW Cross-Validation Checks (Phase 8 Code Generation Gate)

| # | Check | Criteria | Verify Method |
|---|-------|----------|--------------|
| 41 | Entity-VSAM Consistency | Every Entity field maps to a COPYBOOK/VSAM field; no invented fields | Compare Entity field count vs COPYBOOK field count |
| 42 | BMS-DTO Consistency | Every UNPROT field appears in Request DTO; every PROT field appears in Response DTO | Cross-reference Phase 3 field inventory with Phase 8 DTO specs |
| 43 | Program-Service Consistency | Every COBOL program has a corresponding Service class with methods for every paragraph | Compare paragraph count in Phase 5 vs method count in Phase 8 |
| 44 | Repository-IO Consistency | Every VSAM file access (READ/WRITE/STARTBR) in Phase 5 has a Repository method in Phase 8 | Cross-reference Phase 5 File I/O with Phase 8 Repository |
| 45 | API-Screen Consistency | Every BMS map has at least one GET + one POST endpoint in Phase 8 Controller | Count BMS maps in Phase 3 vs Controller endpoints in Phase 8 |
| 46 | Exception-Error Consistency | Every error condition (RESP code handling, IF validation) in Phase 5 has an exception + HTTP status in Phase 8 | Cross-reference Phase 5 Error Handling with Phase 8 Exception spec |
| 47 | Validation-Bean Consistency | Every validation rule in Phase 5 has a Bean Validation annotation AND a test case in Phase 7 | Cross-reference Phase 5 Validation Rules with Phase 8 DTOs and Phase 7 test matrix |
| 48 | Batch-JCL Consistency | Every JCL job has a Spring Batch Job configuration with matching Step sequence | Cross-reference JCL steps with Phase 8 Batch Config |
| 49 | Security-Access Consistency | Every USRSEC user type check in COBOL code has @PreAuthorize in Java | Cross-reference Phase 5 UserType checks with Phase 8 Security spec |
| 50 | No-Guessing Rule | Every Java field, method, class, and DTO has a source reference comment tracing back to COBOL file + line | Grep ALL Java code for `// Source:` comments; count vs total elements |

### NEW Phase 8a/8b/8c Checks (DTO, Flyway, OpenAPI — v4 Enhancements)

| # | Check | Criteria | Verify Method |
|---|-------|----------|--------------|
| 51 | DTO Completeness | Every BMS map has Request + Response DTO pair with ALL UNPROT/PROT fields mapped | Compare Phase 3 BMS inventory with Phase 8a DTO classes |
| 52 | Bean Validation Completeness | Every COBOL IF validation rule has corresponding Bean Validation annotation | Grep COBOL IF-checks vs @Valid/@NotNull/@NotBlank/@Size |
| 53 | Flyway Table Completeness | Every VSAM/DB2/IMS entity has a CREATE TABLE in V1__initial_schema.sql | Count entities in Phase 2 + 4 vs CREATE TABLE count |
| 54 | Flyway FK Completeness | Every COPYBOOK FK relationship has ALTER TABLE foreign key | Compare Phase 2 FK list with V2 FK constraints |
| 55 | Flyway AIX → Index | Every VSAM AIX has corresponding CREATE INDEX in V2 | Compare Phase 2 AIX list with V2 indexes |
| 56 | Flyway Check Constraints | Every 88-level enum has CHECK constraint in V2 | Compare Phase 4 enum list with V2 CHECK constraints |
| 57 | Flyway Seed Data | All lookup/reference tables have seed INSERT statements | V3 INSERT count ≥ reference table count |
| 58 | OpenAPI Endpoint Completeness | All Phase 8 REST endpoints appear in openapi-spec.yaml paths | Endpoint count in Phase 8 vs OpenAPI path count |
| 59 | OpenAPI Schema Completeness | All Phase 8a DTO classes appear as OpenAPI schema components | DTO count in Phase 8a vs OpenAPI schema count |
| 60 | OpenAPI Source References | Every endpoint description includes COBOL source reference | Grep OpenAPI spec for BMS file names |

### NEW Sub-Application Coverage Checks (v4 Enhancements)

| # | Check | Criteria | Verify Method |
|---|-------|----------|--------------|
| 61 | Sub-App File Coverage | ALL sub-application .cbl/.cpy/.bms/.jcl files inventoried and analyzed | Compare Phase 1 sub-app counts with sub-app directory ls |
| 62 | IMS DBD/PSB Coverage | ALL IMS DBD and PSB files documented with segment structure | Count .dbd + .psb files vs Phase 1 inventory |
| 63 | DB2 DDL/DCL Coverage | ALL DB2 DDL and DCL files inventoried with table mappings | Count .ddl + .dcl files vs Phase 1 inventory |
| 64 | COMP-3 Field Inventory | ALL COMP-3 fields across entire project identified with hex layout | Grep COMP-3 in all .cbl files vs Phase 4 COMP-3 section |
| 65 | MQ Message Coverage | ALL MQGET/MQPUT/MQPUT1 in any program documented with queue names and format | Grep MQ commands vs Phase 5 MQ documentation |
| 66 | ASM/Maclib Coverage | ALL assembler and maclib files analyzed with Java replacement strategy | Count .asm + .mac files vs Phase 1 inventory |
| 67 | Scheduler Coverage | ALL scheduler files (CA7, Control-M, etc.) mapped to K8s CronJob or Spring @Scheduled | Count scheduler files vs Phase 6 scheduler mapping |
| 68 | Security Audit Report | Security audit output documents ALL plaintext/anomalous patterns with remediation | Audit report section exists in Phase 8 deliverables |

## Verification Anchor Points

After each phase, self-check these 3 anchors before proceeding:

| Phase | Structure Anchor | Content Anchor | Completeness Anchor |
|-------|-----------------|---------------|-------------------|
| 1 | 00-portfolio/ + 01-source-inventory/ exist | Inventory table has program names | File count matches source |
| 2 | 02-vsam-analysis/ exists | File-to-Entity mapping table present | All VSAM SELECT statements mapped |
| 3 | 03-bms-analysis/ exists | BMS→REST mapping table present, LENGTH→@Column mapping verified | All .bms files mapped; every map has ≥ 8 sections |
| 4 | 04-copybook-analysis/ exists | Field mapping table + REPLACING Registry present | All .cpy files parsed, all REPLACING traced |
| 5 | 05-program-logic/ exists | Business rules table + ALL programs analyzed with 12 sections each | ALL .cbl programs done; paragraph count matches source; every IF/EVALUATE documented |
| 6 | 06-architecture/ exists | Mermaid diagrams render | All dependencies mapped; every program assigned to one service |
| 7 | 07-test-matrix/ exists | Test scenarios table + Golden baseline confidence tags present | ≥ 3 tests per program |
| 8 | 08-deliverables/ has >= 12 files | All Java code compilable, cross-validation checks 41-50 pass | All specs complete; every element has source reference |

## Delivery Checklist

### Portfolio Assessment
- [ ] Application inventory with asset counts, LOC, complexity
- [ ] Each program classified: Retire/Retain/Rehost/Rehost/Refactor/Rewrite
- [ ] Dead code identified (>12 months inactive, unreferenced COPYBOOKs)
- [ ] Complexity metrics computed (cyclomatic, I/O ops, external deps)
- [ ] Migration priority scoring per program (see scoring table below)

### Migration Priority Scoring

| Factor | Weight | Calculation |
|--------|--------|-------------|
| Lines of code | 1 point / 100 LOC | 500 LOC → 5 points |
| File I/O operations | 3 points each | 5 VSAM ops → 15 points |
| CALL/COPY dependencies | 2 points each | 4 COPYBOOKs → 8 points |
| EVALUATE/IF branches | 1 point / 5 branches | 30 branches → 6 points |
| COMPUTE/ARITHMETIC ops | 2 points each | 8 COMPUTEs → 16 points |
| CICS commands | 2 points each | 10 CICS cmds → 20 points |
| COMP-3 fields accessed | 3 points each | 4 COMP-3 → 12 points |
| Screen (BMS) complexity | 1 point / 10 fields | 40 fields → 4 points |

| Score Range | Priority | Migration Order |
|-------------|----------|----------------|
| 0-10 | LOW | Wave 3 |
| 11-30 | MEDIUM | Wave 2 |
| 31-60 | HIGH | Wave 1 |
| 60+ | CRITICAL | Wave 1 (senior devs) |

### Analysis Completeness
- [ ] Every .cbl file analyzed and documented
- [ ] Every .cpy file parsed and mapped to Entity
- [ ] Every .bms file mapped to REST API endpoint
- [ ] Every VSAM file mapped to Repository
- [ ] All 88-level conditions extracted as Enums
- [ ] All COBOL formulas translated to BigDecimal operations
- [ ] All COBOL validations translated to Bean Validation
- [ ] All COBOL SYNCPOINT translated to @Transactional
- [ ] All COBOL batch jobs translated to Spring Batch
- [ ] Complete pom.xml (Spring Boot 3.3.x, Java 21)
- [ ] Complete application.yml
- [ ] Complete DDL SQL
- [ ] Mermaid diagrams verified rendering
- [ ] Every architecture node traced to real COBOL entity
- [ ] Every flowchart node traced to real COBOL paragraph
- [ ] business-rules.md covers all extracted rules
- [ ] All entities use Lombok
- [ ] All UPDATE operations have locking strategy
- [ ] All reference queries use @Cacheable
- [ ] All list queries support cursor-based pagination
- [ ] All COPY REPLACING statements traced in REPLACING Registry
- [ ] All DFSORT/ICETOOL operations mapped in Data Pipeline documentation
- [ ] All DFHMDF LENGTH values mapped to @Column(length=N) + @Size(max=N)
- [ ] Golden baselines have confidence tags (HIGH/MEDIUM/LOW/UNCERTAIN)
- [ ] AI-derived baselines marked with @Tag("ai-derived") where applicable
- [ ] **Every program analysis has ALL 12 required sections**
- [ ] **Every BMS map has ALL 8 required sections**
- [ ] **Cross-validation checks 41-50 all pass**

### Phase 8 Code Generation Gate (NEW)
- [ ] All Entity classes have complete Java code (no pseudocode)
- [ ] All Repository interfaces have complete Java code (no pseudocode)
- [ ] All Service classes have complete Java code with constructor injection
- [ ] All DTO classes exist for every BMS map (Request + Response)
- [ ] All Controller classes exist for every screen
- [ ] Exception hierarchy + GlobalExceptionHandler complete
- [ ] CursorPageResponse<T> defined for pagination screens
- [ ] All Spring Batch configurations complete (Job + Step + Reader + Writer)
- [ ] SecurityFilterChain + JWT filter code complete
- [ ] OpenAPI 3.0 spec generated
- [ ] All code elements have `// Source:` reference comments
- [ ] **Cross-validation checks 41-50 documented as PASS**

### Session State
- [ ] `_state-snapshot.json` created after each phase
- [ ] `_context-index.md` tracks all processed batches
- [ ] `_kb-reference.md` compact knowledge base for Stage 2
- [ ] `_etl-config.json` VSAM-to-RDBMS mapping
- [ ] `_review-log.md` review feedback documented
- [ ] Resume protocol tested

### ETL & Data Migration
- [ ] `_etl-config.json` with VSAM-to-RDBMS mapping
- [ ] ETL Python script with COMP-3 unpacking
- [ ] ETL validation checklist (record count, balance, null checks)
- [ ] EBCDIC → UTF-8 conversion plan

### Migration Strategy
- [ ] Strangler Fig plan (4 phases)
- [ ] Database coexistence plan (5 phases)
- [ ] Rollback plan per migration phase
- [ ] Dual-write reconciliation process
- [ ] Cutover criteria defined

## Common COBOL → Java Modernization Pitfalls

### Data Format Issues

| Pitfall | COBOL Behavior | Correct Java Approach |
|---------|---------------|----------------------|
| Fixed-width fields | Padded with spaces/zeros | @Column(length=N), trim/pad |
| PIC V implied decimal | V is implied, no point stored | BigDecimal with explicit scale |
| COMP-3 packed decimal | Binary packed, not readable | Comp3Converter.unpack() |
| REDEFINES overlay | Same memory, different views | @Inheritance or separate DTOs |
| FILLER padding | Unused bytes | Document but skip mapping |
| COPY REPLACING | Compile-time field name/text substitution | Always trace REPLACING back to COPYBOOK; use replaced names in Entity; build REPLACING Registry table |
| BMS DFHMDF LENGTH ignored | BMS sets field byte length | Ignoring → missing @Size validation on DTOs, truncated data in DB | Always map LENGTH=N → @Column(length=N) + @Size(max=N) |

### Numeric Precision

| Pitfall | COBOL | Java Default | Correct |
|---------|-------|-------------|---------|
| Division rounding | Truncate toward zero | Depends | Always RoundingMode.HALF_UP |
| Overflow | Silent truncation | Exception/infinity | @Column(precision,scale) + validation |
| Leading zeros | Preserved in PIC 9(N) | Lost in Integer/Long | Use String if leading zeros matter |

### Testing Mistakes

- **Incomplete edge cases**: Only testing success + 1 failure → use Phase 7 test matrix to cover ALL paths
- **Not verifying written files**: Always read back generated files (CRITICAL RULE #8)
- **State pollution**: Use @Transactional test methods that rollback
- **No COBOL baseline**: Document expected COBOL behavior before writing Java

### Concurrency Safety (CRITICAL)

| COBOL Pattern | COBOL Behavior | Naive Java | Production Java |
|--------------|---------------|-----------|-----------------|
| MAX+1 ID generation | Single-thread CICS | `findMaxId() + 1` (RACE!) | Database SEQUENCE / Snowflake |
| READ UPDATE + REWRITE | Implicit CICS lock | Simple save() (LOST UPDATE!) | @Lock(PESSIMISTIC_WRITE) |
| SYNCPOINT boundary | CICS unit of work | Individual saves | @Transactional + @Version |
| Working-Storage | Per-task instance | Singleton field (WRONG!) | Method-local variables |

### Batch Processing Mistakes

| Pitfall | COBOL Behavior | Naive Java | Production Java |
|---------|---------------|-----------|-----------------|
| DFSORT/SORT pipeline skipped | JCL SORT step between COBOL programs transforms data | COBOL programs called directly without the intermediate transform | Reconstruct the full pipeline as Spring Batch steps: extract → transform → aggregate → report |
| ICETOOL operations ignored | SUM/COUNT/SELECT in SYSIN are data processing logic | Data passed through unchanged, losing aggregation/filtering | Map each ICETOOL operation to a Stream/Spring Batch equivalent |
| SORT intermediate file format unknown | SORT step reformats via OUTFIL/REFORMAT | Wrong field positions cause data corruption | Document field layout changes at each pipeline stage in a Data Pipeline table |
| INCLUDE/OMIT conditions lost | SYSIN filter conditions filter rows between programs | All rows passed through, violating business logic | Implement as `stream.filter()` or Spring Batch `ClassifierCompositeItemProcessor` |

## Production Acceptance Checklist

### Code Generation Gate
- [ ] @Lock(PESSIMISTIC_WRITE) for UPDATE operations
- [ ] ID generation uses SEQUENCE/Snowflake (NOT MAX+1)
- [ ] S9(N)V99 fields use BigDecimal with precision/scale
- [ ] SYNCPOINT → @Transactional
- [ ] COBOL validations → Bean Validation
- [ ] INVALID KEY → Optional.orElseThrow()
- [ ] REDEFINES → @Inheritance or separate DTOs
- [ ] ALL Service methods have constructor injection (no @Autowired fields)
- [ ] ALL DTOs have Bean Validation annotations
- [ ] ALL pagination uses cursor-based pattern (NOT offset)
- [ ] GlobalExceptionHandler covers ALL exception types
- [ ] Password migration supports both plain-text and BCrypt

### Data Migration Gate
- [ ] COMP-3 round-trip golden test passed
- [ ] EBCDIC→UTF-8 checksums verified
- [ ] Row count reconciliation (source = target)
- [ ] Numeric checksums within 1e-10 tolerance
- [ ] No orphan records
- [ ] All unique constraints validated

### Security Gate
- [ ] OWASP: 0 CRITICAL, 0 HIGH
- [ ] Container scan: 0 CRITICAL, 0 HIGH
- [ ] Plain-text → BCrypt migration done
- [ ] PII fields encrypted at rest
- [ ] JWT expiration < 1 hour
- [ ] API rate limiting configured

### Performance Gate
- [ ] P95 <= COBOL baseline × 1.2
- [ ] P99 <= COBOL baseline × 1.5
- [ ] Concurrent users >= COBOL × 2
- [ ] Error rate < 0.1% (24h)
- [ ] DB pool not saturated
- [ ] GC pause < 50ms (P99)

### API Contract Gate
- [ ] All BMS→REST contracts verified
- [ ] Error responses match COBOL messages
- [ ] HTTP status codes match COBOL patterns
- [ ] Consumer contract tests pass (Pact)

### CI/CD Gate
- [ ] Unit tests pass (mvn test)
- [ ] Integration tests pass (mvn verify)
- [ ] JaCoCo >= 80%
- [ ] SonarQube Quality Gate passed
- [ ] Docker image built & pushed
- [ ] Staging deployment verified
- [ ] E2E tests passed

### Production Cutover Gate
- [ ] Dual-write >= 7 days with 0 discrepancies
- [ ] Feature flags for instant rollback
- [ ] Rollback rehearsed (< 5 min)
- [ ] Monitoring configured (Prometheus + Grafana)
- [ ] Alerts configured (P99 threshold, error rate)
- [ ] On-call rotation assigned
- [ ] Business stakeholders signed off
