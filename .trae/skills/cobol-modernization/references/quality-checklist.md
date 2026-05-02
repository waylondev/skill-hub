# Quality Checklist & Common Pitfalls

## Mandatory QA Checks

All checks MUST pass before delivery. If ANY fails, regenerate the deficient deliverable.

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
| 17 | Pagination | All list operations support Pageable | Check repository signatures |
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
| 31 | REPLACING Coverage | All COPY REPLACING statements traced to COPYBOOK | Check COPY REPLACING Registry in copybook-data-structures.md |
| 32 | DFSORT/ICETOOL Coverage | All JCL SORT steps mapped to Java Stream / Spring Batch | Check Data Pipeline documentation in program-logic-analysis.md |
| 33 | BMS LENGTH Mapping | All DFHMDF LENGTH=N mapped to @Column/@Size | Check DTO @Size annotations vs BMS LENGTH values |
| 34 | Golden Baseline Confidence | All AI-derived baselines have confidence tags | Check @Tag("confidence-high/medium/low") presence |
| 35 | Token Budget Compliance | Stage 2 uses _kb-reference.md, not full docs | Verify Stage 2 codegen only reads compact knowledge base |

## Verification Anchor Points

After each phase, self-check these 3 anchors before proceeding:

| Phase | Structure Anchor | Content Anchor | Completeness Anchor |
|-------|-----------------|---------------|-------------------|
| 1 | 00-portfolio/ + 01-source-inventory/ exist | Inventory table has program names | File count matches source |
| 2 | 02-vsam-analysis/ exists | File-to-Entity mapping table present | All VSAM SELECT statements mapped |
| 3 | 03-bms-analysis/ exists | BMS→REST mapping table present, LENGTH→@Column mapping verified | All .bms files mapped |
| 4 | 04-copybook-analysis/ exists | Field mapping table + REPLACING Registry present | All .cpy files parsed, all REPLACING traced |
| 5 | 05-program-logic/ exists | Business rules table + Data Pipeline documentation present | All .cbl logic extracted, all DFSORT/ICETOOL mapped |
| 6 | 06-architecture/ exists | Mermaid diagrams render | All dependencies mapped |
| 7 | 07-test-matrix/ exists | Test scenarios table + Golden baseline confidence tags present | All code paths covered |
| 8 | 08-deliverables/ has >= 10 files | Entity code compilable, @Size annotations match BMS LENGTH | All specs complete |

## Delivery Checklist

### Portfolio Assessment
- [ ] Application inventory with asset counts, LOC, complexity
- [ ] Each program classified: Retire/Retain/Rehost/Refactor/Rewrite
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
- [ ] All list queries support Pageable
- [ ] All COPY REPLACING statements traced in REPLACING Registry
- [ ] All DFSORT/ICETOOL operations mapped in Data Pipeline documentation
- [ ] All DFHMDF LENGTH values mapped to @Column(length=N) + @Size(max=N)
- [ ] Golden baselines have confidence tags (HIGH/MEDIUM/LOW/UNCERTAIN)
- [ ] AI-derived baselines marked with @Tag("ai-derived") where applicable

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
