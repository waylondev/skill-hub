---
name: "cobol-modernization"
description: "Complete COBOL-to-Java migration framework with portfolio assessment, code analysis, documentation generation, testing matrix, and production migration strategies. Invoke when analyzing COBOL legacy systems, planning COBOL modernization projects, or migrating COBOL/CICS/VSAM to Java Spring Boot."
---

# COBOL Modernization Skill

## Overview

This skill provides a systematic approach to analyzing COBOL legacy systems and generating comprehensive documentation deliverables sufficient to support AI-driven Java Spring Boot code generation.

## When to Invoke

- Analyze COBOL source code for migration purposes
- Request architecture diagrams, flowcharts, or data dictionaries from COBOL code
- Generate documentation for COBOL-to-Java migration projects
- Provide a directory containing COBOL programs (.cbl), COPYBOOKs (.cpy), or BMS Maps (.bms)
- Need standardized analysis output for legacy modernization projects
- Convert COBOL/CICS/VSAM to Java Spring Boot

## Skill Configuration Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| target-db | postgresql | Target database: postgresql/mysql/oracle |
| spring-boot-version | 3.3.x | Spring Boot version (LTS) |
| java-version | 21 | Java version (LTS) |
| mq-provider | jms | Message queue provider: jms/rabbitmq/kafka |
| security-provider | spring-security | Security provider: spring-security/spring-security-oauth2 |
| include-sub-applications | auto | Analyze optional modules: true/false/auto-detect |
| output-format | markdown | Output format: markdown/confluence/html |
| diagram-style | modern | Mermaid diagram style: modern/standard/minimal |
| api-versioning | v1 | API version prefix: v1/v2/none |
| include-flyway | true | Include Flyway database migration scripts |
| include-gateway | true | Include Spring Cloud Gateway config |
| include-jacoco | true | Include JaCoCo code coverage |
| include-screen-ascii | true | Include BMS ASCII screen layout |
| include-navigation-state-machine | true | Include screen navigation state diagram |
| include-security-audit | true | **NEW** — Include security audit report (Phase 8d) |
| include-mq-catalog | auto | **NEW** — Include MQ message catalog (auto=only if MQ detected) |
| include-batch-deps | auto | **NEW** — Include batch dependency DAG (auto=only if JCL+GDG exist) |
| include-data-model-merge | auto | **NEW** — Include IMS/DB2/VSAM model merge (auto=multi-source) |
| batch-size | 8 | COBOL files per batch processing |
| enable-human-review | true | Enable human review checkpoints (CP-1 to CP-5) |
| chunking-strategy | auto | File processing: auto/module-based/rolling |
| mode | lite | Processing mode: lite (core phases 1-8) / full (all phases 1-10+) / v4-enhanced (includes 8a-8g) |

## CRITICAL RULES

1. **NEVER skip any source file** - Every .cbl/.cpy/.bms/.jcl must be analyzed
2. **NEVER use placeholder text** - All output must contain actual extracted data
3. **ALWAYS trace back to source** - Every Java element must reference COBOL file + line number using `// Source: [filename], line [N]`
4. **ALWAYS generate complete code** - Entity/Repository/Service/DTO must be full working code, not stubs
5. **ALWAYS follow the directory structure** - Output must match the standard template
6. **ALWAYS prioritize completeness** - Better to be thorough than brief
7. **ALWAYS preserve COBOL data format semantics** - Fixed-width fields, PIC clause precision, COMP-3 packing
8. **ALWAYS verify written code files** - Read back generated files to confirm completeness
9. **NEVER assume input/output formats** - Investigate discrepancies fully
10. **NEVER attempt single-session completion on large projects** - Use phased execution
11. **ALWAYS pause at human review checkpoints** - Wait for user confirmation at CP-1 through CP-5
12. **USE analysis docs as context for Stage 2** - During code generation, read from 00-07 directory documents
13. **MAINTAIN context index** - Track processed files to enable resume
14. **ANALYZE EVERY .cbl PROGRAM's PROCEDURE DIVISION** - No program may be skipped; if context limit reached, save state and resume in next session
15. **GENERATE CODE-LEVEL SPECS, NOT HIGH-LEVEL DESCRIPTIONS** - Every deliverable must be detailed enough for AI to generate compilable Java code without guessing
16. **ALWAYS GENERATE DTO CLASSES WITH VALIDATION** - Every Request DTO must have Bean Validation annotations extracted from COBOL IF rules; no annotation-less DTOs
17. **ALWAYS GENERATE FLYWAY SCRIPTS** - If include-flyway=true (default), generate V1__initial_schema.sql from VSAM/DB2/IMS data dictionaries, NOT from invented schemas
18. **ALWAYS AUDIT SECURITY** - Plaintext passwords, unencrypted PII, missing RBAC must be flagged in security-audit.md
19. **ALWAYS ANALYZE MQ MESSAGE FORMATS** - If MQGET/MQPUT found in source, generate complete message schemas with field-level precision

## Phase Output Precision Standards (NEW — Minimum Acceptable Quality)

| Phase | Output Type | Minimum Precision | AI Code-Generation Ready? |
|-------|-------------|-------------------|--------------------------|
| Phase 1 (Discovery) | File inventory table | Every file listed with type, size estimate, sub-app module | N/A — metadata only |
| Phase 2 (VSAM) | Data dictionary | Every field: name, PIC, length, PK/FK, JPA type, column name | Yes for Entity generation |
| Phase 3 (BMS) | Screen specs | **Every** BMS map: ALL field names, attributes (PROT/UNPROT), PIC, Java type, validation | Yes for DTO generation |
| Phase 4 (COPYBOOK) | Data structures | Every level number, field, PIC, REDEFINES target, OCCURS count, 88-level values | Yes for Entity + Enum generation |
| Phase 5 (Logic) | Program analysis | **Every program**: paragraph-to-method map, ALL IF/EVALUATE branches, ALL COMPUTE formulas, ALL validation rules, state machine (if applicable), CICS commands | **Must be YES** for Service generation |
| Phase 6 (Architecture) | Architecture doc | Call graph, service boundaries, inter-service protocol (REST/gRPC/MQ), batch step sequence | Yes for service scaffolding |
| Phase 7 (Test Matrix) | Test cases | Test ID, input, expected output, source program/line, golden test fixture path | Yes for test generation |
| Phase 8 (Deliverables) | Java specs | **Complete Java code**: Entity, Repository, Service, Controller, DTO, Exception, Enum, Config | **Must be YES** for compilation |
| Phase 8a (DTO) | DTO classes | **Complete DTO** with Bean Validation annotations for every UNPROT BMS field, error message strings from COBOL | Yes for API contract generation |
| Phase 8b (Flyway) | SQL scripts | **Complete Flyway** V1+V2+V3: every VSAM/DB2/IMS table, all FKs, all AIX→index, CHECK constraints, seed data | Yes for DB initialization |
| Phase 8c (OpenAPI) | YAML spec | **Complete OpenAPI 3.0**: every endpoint, every schema, source references in descriptions | Yes for Swagger UI + Client SDK |
| Phase 8d (Security) | Audit report | All plaintext passwords, PII fields, missing RBAC patterns with Java remediation code | Yes for compliance audit |
| Phase 8e (Batch Deps) | DAG + Scheduler | Every JCL job in dependency graph, COND→Flow translation, CA7/Control-M→CronJob | Yes for batch orchestration |
| Phase 8f (MQ Catalog) | Message schemas | Every MQ queue/format with field-level schema, CorrelID pattern, RabbitMQ topology | Yes for MQ migration |
| Phase 8g (Data Merge) | Unified model | All VSAM+DB2+IMS entities merged, deduplicated, normalized, with migration sequence | Yes for final schema |

### Per-Program Logic Analysis Minimum Requirements (Phase 5)

For **each** COBOL program, the analysis MUST include:

1. **Complete Paragraph Inventory** — Every paragraph/section name with line number
2. **Complete Branch Map** — Every IF/ELSE/EVALUATE/WHEN with its condition and source line
3. **Complete File I/O Operations** — Every READ/WRITE/REWRITE/STARTBR/READNEXT/READPREV/ENDBR with file name, key field, RESP handling
4. **Complete Screen I/O** (CICS) — Every SEND MAP/RECEIVE MAP with field-level mapping
5. **Complete Validation Rules** — Every IF-check that rejects input, with the error message and field
6. **Complete State Transitions** (if multi-state) — State name, trigger, target state
7. **Complete Variable Usage** — Working-storage variables that hold business data (not just WS-RESP-CD)
8. **CommArea Structure** — If program uses commarea, list every field accessed and its purpose

**If any of the above is missing for a program, the analysis is INCOMPLETE and must be regenerated.**

### Per-BMS-Map Analysis Minimum Requirements (Phase 3)

For **each** BMS map, the analysis MUST include:

1. **Every DFHMSD field** — Field name, position (row/column), PIC, attribute (PROT/UNPROT/DRAG), initial value
2. **Input Field Mapping** — UNPROT fields → Request DTO field with validation rule
3. **Output Field Mapping** — PROT fields → Response DTO field
4. **Map Flow** — Which program SENDs this map, which program RECEIVEs, what happens on each PF key
5. **Cross-Reference** — If map field references a COPYBOOK field (e.g., `TRAN-ID` from `CVTRA05Y`), note the link

**If a project has >10 BMS maps, analyze ALL of them. No shortcuts.**

## Execution Flow

### Step 0: Validate Input Environment (MANDATORY — execute before any analysis)

Before ANY analysis begins, verify the following:

| Check | Action if Missing |
|-------|-------------------|
| Source directory path is provided | Prompt user: "Please provide the directory path containing COBOL source files (.cbl/.cpy/.bms/.jcl)" |
| Source directory exists on disk | Prompt user: "The specified directory does not exist. Please check the path." |
| At least one .cbl or .cpy file found | If only JCL/BMS: proceed with limited analysis and warn user "No COBOL program files found; analysis will be limited to JCL/BMS content only" |
| Files are readable (not binary, not encrypted) | Skip unreadable files, document in source inventory as `[UNREADABLE]` |

**Output after validation:** Generate a confirmation summary:

```markdown
## Input Environment Confirmed
- **Source Directory:** [absolute path]
- **Files Found:** [N] .cbl, [N] .cpy, [N] .bms, [N] .jcl
- **Processing Mode:** lite / full (based on file count + user request)
- **Ready to proceed:** YES / NO (check with user if NO)
```

### Step 1: Determine User Intent

| User Request Pattern | Action |
|---------------------|--------|
| "分析这个COBOL项目" / "Analyze this COBOL project" | Execute ALL Core Phases 1-8 sequentially |
| "分析这个程序的代码逻辑" / "Analyze program logic" | Execute Phase 1 (scan) + Phase 5 (logic analysis) only |
| "生成迁移文档" / "Generate migration docs" | Execute Core Phases 1-8 |
| "生成Java代码" / "Generate Java code" | Execute Core Phases 1-8, then Phase 9 (AI Code Generation) |
| "完整迁移到生产环境" / "Full production migration" | Execute ALL phases including extended phases |

### Step 2: Phased Execution Mechanism (CRITICAL)

Split work into two distinct stages with a manual checkpoint:

| Stage | Phases | Purpose | Output |
|-------|--------|---------|--------|
| **Stage 1: Analysis** | 1-7 | Parse source, extract structures, identify dependencies, build test matrix | Analysis documents in 00-07 directories |
| **--- HUMAN REVIEW CHECKPOINT ---** | | **Pause and let user verify analysis accuracy** | |
| **Stage 2: Generation** | 8-20 | Generate Java code, configs, tests, and deployment artifacts | Complete deliverables in 08+ directories |

**Execution Protocol:**
1. Execute Stage 1 (Phases 1-7) completely
2. STOP and prompt user: "Analysis complete. Please review documents in 00-07 directories. Reply 'continue' to start code generation."
3. After user confirms, execute Stage 2 using ONLY analysis documents as context (NOT original COBOL source)

### Step 3: Quality Gate Enforcement

After ALL phases complete, run Mandatory Checks from `references/quality-checklist.md`. If ANY check fails, regenerate the deficient deliverable before final delivery.

## Phase Index

### Stage 1: Analysis Phases (1-7)

| # | Phase | Document | Purpose |
|---|-------|----------|---------|
| 1 | Source Discovery | [phases/01-discovery.md](phases/01-discovery.md) | Scan & classify all source files |
| 2 | VSAM Analysis | [phases/01-discovery.md](phases/01-discovery.md#phase-2-vsam-file-analysis) | VSAM → JPA Repository mapping |
| 3 | BMS Analysis | [phases/02-screens.md](phases/02-screens.md) | BMS Map → REST API mapping |
| 4 | COPYBOOK Analysis | [phases/03-copybook.md](phases/03-copybook.md) | Data structure → JPA Entity mapping |
| 5 | Program Logic | [phases/04-logic.md](phases/04-logic.md) | Business logic → Service implementation |
| 6 | Architecture | [phases/05-architecture.md](phases/05-architecture.md) | Dependency graph + microservice split + JCL mapping + security |
| 7 | Test Matrix | [phases/06-testing.md](phases/06-testing.md) | Test matrix + golden test baseline |

### Stage 2: Generation Phases (8-20)

| # | Phase | Document | Purpose |
|---|-------|----------|---------|
| 8 | Core Deliverables | [phases/07-deliverables.md](phases/07-deliverables.md) | Entity/Repo/Service/API specifications |
| 8a | DTO & Validation | [phases/10-dto-specification.md](phases/10-dto-specification.md) | **NEW** — Complete DTO classes with Bean Validation from COBOL IF rules |
| 8b | Flyway Migrations | [phases/11-flyway-migration.md](phases/11-flyway-migration.md) | **NEW** — Flyway SQL from VSAM/DB2/IMS data dictionaries |
| 8c | OpenAPI 3.0 | [phases/12-openapi.md](phases/12-openapi.md) | **NEW** — OpenAPI 3.0 YAML from BMS/REST endpoint mappings |
| 8d | Security Audit | [phases/13-security-audit.md](phases/13-security-audit.md) | **NEW** — Plaintext passwords, encryption gaps, RBAC mapping |
| 8e | Batch Dependencies | [phases/14-batch-deps.md](phases/14-batch-deps.md) | **NEW** — JCL/GDG dependency DAG → Spring Batch Flow + K8s CronJob |
| 8f | MQ Catalog | [phases/15-mq-catalog.md](phases/15-mq-catalog.md) | **NEW** — MQ message format schemas + RabbitMQ topology |
| 8g | Data Model Merge | [phases/16-data-model-merge.md](phases/16-data-model-merge.md) | **NEW** — IMS/DB2/VSAM unified relational model |
| 9 | Code Generation | [phases/08-codegen.md](phases/08-codegen.md) | AI code generation + golden examples |
| 10+ | Deployment | [phases/09-deployment.md](phases/09-deployment.md) | Frontend, CI/CD, K8s, monitoring, compliance |

## Reference Library

| Document | Content |
|----------|---------|
| [references/cobol-to-java-mappings.md](references/cobol-to-java-mappings.md) | COBOL→Java type/PIC/CICS/JCL mapping tables |
| [references/golden-examples.md](references/golden-examples.md) | Production-grade code examples (Phase 9.5 standard) |
| [references/quality-checklist.md](references/quality-checklist.md) | QA mandatory checks + delivery checklist + pitfalls (68 checks) |
| [references/production-patterns.md](references/production-patterns.md) | Migration strategies + deployment patterns |
| [phases/cp-review-protocol.md](phases/cp-review-protocol.md) | **NEW** — Human review checkpoint protocol (CP-1 to CP-5) |

## Human Review Checkpoints

| Checkpoint | After Phase | Review Focus | Who |
|-----------|-------------|--------------|-----|
| **CP-1** | Phase 4 (COPYBOOK) | Entity relationships, field mappings, COMP-3 handling | DBA + COBOL developer |
| **CP-2** | Phase 5 (Program Logic) | Computation formulas, validation rules, edge cases | Business analyst + COBOL developer |
| **CP-3** | Phase 6 (Architecture) | Service boundaries, module dependencies | Solution architect |
| **CP-4** | Phase 7 (Test Matrix) | Test scenarios coverage, golden test baselines | QA lead + COBOL developer |
| **CP-5** | Phase 9 (Code Gen) | Java code completeness, pattern correctness | Java developer + architect |

At each checkpoint:
1. Generate a "Review Summary" document
2. Wait for user confirmation before proceeding
3. If issues flagged, re-run the relevant phase
4. Document all feedback in `_review-log.md`

## Session State Management

### State Files (CRITICAL for large projects)

| File | Purpose | Update Frequency |
|------|---------|-----------------|
| `_state-snapshot.json` | Current phase, batch progress, review status | After EVERY phase |
| `_context-index.md` | Files processed per batch, key elements extracted | After EVERY batch |
| `_kb-reference.md` | Compact knowledge base for Stage 2 | After Stage 1 complete |
| `_etl-config.json` | VSAM-to-RDBMS migration configuration | After Phase 2 complete |
| `_review-log.md` | Human review feedback and decisions | At each checkpoint |

### State Snapshot Template (`_state-snapshot.json`)

```json
{
  "project": "<project-name>",
  "analysis-date": "YYYY-MM-DD",
  "current-phase": 5,
  "current-batch": 3,
  "total-batches": 10,
  "stage": "analysis",
  "phase-status": {
    "1": "completed",
    "2": "completed",
    "3": "completed",
    "4": "completed",
    "5": "in-progress",
    "6": "pending",
    "7": "pending",
    "8": "pending"
  },
  "files-processed": [
    "COSGN00C.cbl",
    "COMEN01C.cbl",
    "COADM01C.cbl"
  ],
  "files-pending": [
    "COACTUPC.cbl",
    "COACTVWC.cbl",
    "COCRDLIC.cbl"
  ],
  "review-checkpoints": {
    "CP-1": "passed",
    "CP-2": "pending",
    "CP-3": "pending",
    "CP-4": "pending",
    "CP-5": "pending"
  },
  "resume-instructions": "Read _context-index.md for processed files. Start Phase 5 batch 4."
}
```

### Context Index Template (`_context-index.md`)

```markdown
# Context Index — <project-name>

## Phase Progress

| Phase | Status | Batches Completed | Last Updated |
|-------|--------|-------------------|-------------|
| 1. Discovery | DONE | 1/1 | YYYY-MM-DD |
| 2. VSAM | DONE | 1/1 | YYYY-MM-DD |
| 3. BMS | DONE | 2/2 | YYYY-MM-DD |
| 4. COPYBOOK | DONE | 1/1 | YYYY-MM-DD |
| 5. Logic | IN-PROGRESS | 3/10 | YYYY-MM-DD |
| 6. Architecture | PENDING | 0/1 | - |
| 7. Test Matrix | PENDING | 0/1 | - |
| 8. Deliverables | PENDING | 0/1 | - |

## Files Processed

### Phase 1 — Discovery
- [x] All files scanned, inventory complete

### Phase 2 — VSAM
- [x] vsam-data-dictionary.md generated

### Phase 3 — BMS
- [x] bms-map-analysis.md generated (17 maps)

### Phase 4 — COPYBOOK
- [x] copybook-data-structures.md generated (29 copybooks)

### Phase 5 — Logic (Batch Processing)
- [x] Batch 1: COSGN00C, COMEN01C, COADM01C (authentication + menu)
- [x] Batch 2: COACTUPC, COACTVWC (account operations)
- [x] Batch 3: COCRDLIC, COCRDSLC, COCRDUPC (card operations)
- [ ] Batch 4: COTRN00C, COTRN01C, COTRN02C (transaction operations)
- [ ] Batch 5: COBIL00C, CORPT00C (billing + reports)
- [ ] Batch 6: COUSR00C, COUSR01C, COUSR02C, COUSR03C (user management)
- [ ] Batch 7: Batch processing programs (CB*)
- [ ] Batch 8: Sub-application modules

## Key Elements Extracted

### Entities
- Customer, Account, Card, CardXref, Transaction, TranType, TranCat, TranCatBal, DiscGroup, UserSecurity

### 88-Level Enums
- UserType (ADMIN/USER), CardStatus (ACTIVE/INACTIVE), ProgramContext (ENTER/REENTER)

### PF Key Mappings
- ENTER=submit, PF3=exit, PF5=save, PF7=prev-page, PF8=next-page, PF12=cancel

### State Machines
- Card Update: NOT_FETCHED → SHOW_DETAILS → CHANGES_NOT_OK / CHANGES_OK → SAVED
```

### Resume Protocol

1. Read `_state-snapshot.json` for last completed phase
2. Read `_context-index.md` for processed files
3. Skip already-processed files; only process pending
4. If resuming mid-phase, re-read last deliverable and continue appending

## Output Directory Structure

```
project-name/
├── README.md
├── _state-snapshot.json              # [STATE] Phase/batch/review progress
├── _context-index.md                 # [TRACKING] Files processed per batch
├── _review-log.md                    # [TRACKING] Human review decisions
├── _kb-reference.md                  # [KB] Compact knowledge base for Stage 2
├── _etl-config.json                  # [ETL] VSAM-to-RDBMS migration config
├── 00-portfolio/
│   └── portfolio-assessment.md
├── 01-source-inventory/
│   └── source-file-inventory.md
├── 02-vsam-analysis/
│   ├── vsam-data-dictionary.md
│   └── vsam-aix-mapping.md           # [IF AIX exists]
├── 03-bms-analysis/
│   ├── bms-map-analysis.md
│   └── screen-navigation-state-machine.md  # [IF enabled]
├── 04-copybook-analysis/
│   ├── copybook-data-structures.md
│   └── unified-data-model.md          # [NEW v4 — Phase 8g] IMS/DB2/VSAM merged model
├── 05-program-logic/
│   └── program-logic-analysis.md
├── 06-architecture/
│   ├── architecture-diagrams.md
│   ├── scheduler-mapping.md          # [IF scheduler exists]
│   └── batch-dependency-graph.md     # [NEW v4 — Phase 8e] JCL/GDG dependency DAG
├── 07-test-matrix/
│   └── test-matrix.md
├── 08-deliverables/
│   ├── entity-specification.md
│   ├── repository-specification.md
│   ├── service-implementation-guide.md
│   ├── enums-constants.md
│   ├── rest-api-specification.md
│   ├── risk-analysis-migration-guide.md
│   ├── project-config.md
│   ├── vsam-data-formats.md
│   ├── jcl-batch-mapping.md
│   ├── business-rules.md
│   ├── security-mapping.md
│   ├── dto-specification.md          # [NEW v4 — Phase 8a] Complete DTO classes
│   ├── exception-handling.md         # Exception hierarchy + GlobalExceptionHandler
│   ├── openapi-spec.yaml             # [NEW v4 — Phase 8c] OpenAPI 3.0 spec
│   ├── security-audit.md             # [NEW v4 — Phase 8d] Security findings + remediation
│   └── mq-message-catalog.md         # [NEW v4 — Phase 8f] MQ format schemas
├── 09-database-migrations/           # [IF include-flyway=true]
│   ├── V1__initial_schema.sql
│   ├── V2__indexes_and_constraints.sql
│   └── V3__seed_data.sql
└── 10-cicd-pipeline/                 # [IF full mode]
    ├── Jenkinsfile
    └── .github/workflows/ci-cd.yml
```

## Exception Handling Guidance

| Feature Not Found | Action | Output Note |
|-------------------|--------|-------------|
| No DB2 code (no EXEC SQL) | Skip DB2 analysis | "No DB2 integration found in source" |
| No IMS code (no EXEC DLI) | Skip IMS analysis | "No IMS DB integration found in source" |
| No MQ code (no MQGET/MQPUT) | Skip MQ analysis | "No MQ integration found in source" |
| No COBOL programs (.cbl) | Analyze COPYBOOKs/BMS/JCL only | "No COBOL program files found; analysis limited" |
| No Assembler calls | Skip Assembler replacement | "No Assembler program calls found" |
| No JCL files | Skip JCL→Batch mapping | "No JCL files found; skip batch analysis" |
| No BMS files | Skip BMS→REST mapping | "No BMS map files found; skip screen analysis" |
| No COMP-3 fields | Skip COMP-3 section | "No COMP/COMP-3 fields found" |
| No REDEFINES | Skip REDEFINES section | "No REDEFINES clauses found" |
| No OCCURS clauses | Skip OCCURS section | "No OCCURS/OCCURS DEPENDING ON clauses found" |
| No COPY REPLACING statements | Skip REPLACING Registry | "No COPY REPLACING statements found; field names use COPYBOOK originals" |
| No DFSORT/ICETOOL/SORT steps in JCL | Skip Data Pipeline reconstruction | "No DFSORT/ICETOOL steps found in JCL; skip pipeline analysis" |

## Processing Mode Selection

| Mode | Scope | Output | Use Case |
|------|-------|--------|----------|
| `lite` | Core phases 1-9 | Core analysis + entity specs + service guides + DTOs + exceptions | Small projects < 50 COBOL programs, quick assessments |
| `full` | All 20+ phases | All deliverables + microservice architecture + CI/CD + deployment | Enterprise projects |

## Language Policy

- **User-facing documentation** (explanations, summaries): Match the user's input language
- **Technical deliverables** (code, configuration, SQL, Mermaid): Use English
- **File names and directories**: Use English with kebab-case
- **Code comments**: English, with COBOL source reference format `// Source: [filename], lines [start]-[end]`
- **Business rule descriptions**: Match user language for clarity

## File Size Handling

When content exceeds output limits:
1. Split into logically separate files (e.g., `entity-specification-part1.md`, `entity-specification-part2.md`)
2. Each part MUST include `<!-- Part X of Y -->`
3. The first part MUST contain a table of contents linking to all parts
4. NEVER truncate content to fit limits

## Token Budget Guidelines (Context Window Management)

For large projects (50+ COBOL programs), the full analysis document set may exceed AI context windows. Use the following loading strategy to stay within budget.

### Stage 1: Analysis Phase — Context Loading Strategy

| Phase | Load Full Documents | Load Compact Only | Notes |
|-------|--------------------|--------------------|-------|
| Discovery (1) | Source files being scanned | SKILL.md + phases/01-discovery.md | Read only the .cbl/.cpy being processed |
| VSAM (2) | SELECT/ASSIGN statements + COPYBOOK texts | _kb-reference.md | If _kb-reference.md exists from prior run |
| BMS (3) | .bms files + .cbl with MAP references | _kb-reference.md | |
| COPYBOOK (4) | ALL .cpy files being analyzed | cobol-to-java-mappings.md (reference only) | .cpy files are part of analysis input |
| Logic (5) | One .cbl program at a time | _kb-reference.md + cobol-to-java-mappings.md | NEVER load all .cbl files into context at once |
| Architecture (6) | Phase 1-5 analysis output summaries (NOT full documents) | _context-index.md | Summarize from context-index, not full docs |
| Test Matrix (7) | Phase 5 logic analysis (1 program at a time) | _kb-reference.md | |
| Deliverables (8) | All Phase 1-7 analysis documents (summaries only) | _kb-reference.md | This is the most context-heavy phase |

### Stage 2: Code Generation — Context Loading Strategy

| Phase | Load | Do NOT Load |
|-------|------|-------------|
| Code Gen (9) | `_kb-reference.md` + ONE analysis document at a time + `references/golden-examples.md` | Original COBOL source files (already analyzed in Stage 1) |
| Deployment (10+) | `_kb-reference.md` + ONE deliverable at a time | Analysis documents (00-07 directories) |

### Token-Saving Rules

1. **Prefer `_kb-reference.md` over full documents** — It contains distilled summaries
2. **Process one program/COPYBOOK at a time** — Update state after each
3. **Use `_context-index.md` for cross-referencing** — It tracks what was already processed
4. **If resuming, read `_state-snapshot.json` first** — Skip already-completed phases
5. **Mermaid diagrams are generated, not loaded** — Do not load diagram syntax into context; generate from code analysis

### Large File Splitting Strategy (Token-Aware)

When a deliverable file exceeds reasonable size limits:

1. Create `filename-part-1-of-N.md`, `filename-part-2-of-N.md`, etc.
2. Each part file MUST begin with `> Part X of N — continued from part X-1`
3. Part 1 MUST contain a table of contents with links to all parts
4. NEVER truncate content — split into the exact number of parts needed

## Cross-Validation Rules (NEW — Prevent Data Inconsistency)

These rules ensure data consistency across all phase documents:

1. **Entity-VSAM Cross-Check**: Every field in an Entity MUST have a matching field in the VSAM/COPYBOOK analysis. No invented fields.
2. **BMS-DTO Cross-Check**: Every UNPROT BMS field MUST appear in at least one Request DTO. Every PROT output field MUST appear in at least one Response DTO.
3. **Program-Service Cross-Check**: Every COBOL program analyzed in Phase 5 MUST have a corresponding Service class in Phase 8.
4. **Repository-IO Cross-Check**: Every VSAM file READ/WRITE in Phase 5 MUST have a corresponding Repository method in Phase 8.
5. **API-Endpoint Cross-Check**: Every BMS screen in Phase 3 MUST have at least one REST endpoint in Phase 8.
6. **Exception-Error Cross-Check**: Every error condition in Phase 5 (RESP code handling, IF validation failure) MUST have a corresponding exception type and HTTP status in Phase 8.

## Automated Batch Processing Strategy (NEW — Production Enhancement)

### Module-Based Chunking (for projects with sub-applications)

When `include-sub-applications` is `auto` or `true`, detect sub-applications by directory structure and process each module independently:

| Step | Action | Output |
|------|--------|--------|
| 1 | Scan for sub-directories containing .cbl files | Module inventory |
| 2 | For each module: count .cbl/.cpy/.bms files | Module size assessment |
| 3 | Order modules by dependency (e.g., main → sub-app) | Processing order |
| 4 | Process modules sequentially, updating `_context-index.md` after each | Incremental progress |

### Program Pattern Detection (for Phase 5 automation)

Automatically detect common COBOL program patterns and apply pre-defined analysis templates:

| Pattern | Detection Criteria | Analysis Template |
|---------|-------------------|-------------------|
| **CRUD-Single** | One VSAM file, READ + WRITE/REWRITE operations | Standard CRUD: findById, save, update, delete |
| **CRUD-Master** | Primary VSAM file + cross-reference lookup | Master-detail: findByKey, findByFK, save, update |
| **List-Pagination** | STARTBR + READNEXT/READPREV + screen array | Paginated list: findAll(pageable), findByFilters(pageable) |
| **Search-Then-Display** | RECEIVE MAP → READ → SEND MAP | Search: searchByCriteria → display |
| **Search-Then-Update** | RECEIVE MAP → READ UPDATE → REWRITE | Update: searchById → validate → save |
| **Menu-Dispatcher** | EVALUATE menu-option → XCTL | Router: route(option) → redirect |
| **Batch-Sequential** | Sequential READ of all records + DISPLAY | Batch: processAllRecords() |
| **Batch-Import/Export** | READ from one file → WRITE to another | ETL: read(source) → transform → write(target) |

### State Machine Template (for update programs)

For programs with stateful interaction (e.g., COCRDUPC with search→edit→validate→save):

```
State: NOT_FETCHED → SHOW_DETAILS → CHANGES_NOT_OK / CHANGES_OK → SAVED
Transitions:
  - NOT_FETCHED + Enter(key provided) → SHOW_DETAILS
  - NOT_FETCHED + PF3 → EXIT
  - SHOW_DETAILS + Enter(validation fail) → CHANGES_NOT_OK
  - SHOW_DETAILS + Enter(validation pass) → CHANGES_OK
  - CHANGES_NOT_OK + Enter → SHOW_DETAILS (display errors)
  - CHANGES_OK + PF5 → SAVED
  - CHANGES_OK + Enter → SHOW_DETAILS (review again)
  - CHANGES_OK + PF3 → NOT_FETCHED
  - SAVED + PF3 → NOT_FETCHED
```

## Sub-Application Analysis Strategy (NEW — Production Enhancement)

### Multi-Module Project Detection

When the source directory contains sub-directories with their own COBOL programs, treat each as a separate sub-application:

```
source-root/
├── cbl/              # Main application (always process first)
├── bms/
├── cpy/
├── jcl/
├── app-authorization-ims-db2-mq/   # Sub-app 1
│   ├── cbl/
│   ├── bms/
│   ├── cpy/
│   ├── ims/
│   └── ddl/
└── app-transaction-type-db2/       # Sub-app 2
    ├── cbl/
    ├── bms/
    ├── cpy/
    ├── ddl/
    └── dcl/
```

### Sub-App Processing Order

| Priority | Sub-App Type | Reason |
|----------|-------------|--------|
| 1 | Main CICS/VSAM app | Core functionality, highest user impact |
| 2 | DB2 sub-apps | Reference data, easier to migrate (SQL → JPA) |
| 3 | IMS sub-apps | Legacy DB, higher complexity |
| 4 | MQ sub-apps | Integration layer, depends on above |
| 5 | Assembler | Low-level utilities, lowest priority |

### Sub-App Isolation Rules

1. **Separate output directories** — Each sub-app gets its own analysis directory under the main output
2. **Independent Entity sets** — Sub-apps should NOT share entities with main app unless explicitly referenced
3. **Cross-app calls documented** — If main app XCTLs to sub-app program, document as inter-service call
4. **Shared COPYBOOKs identified** — If sub-app uses same .cpy as main app, note the shared data contract

## Notes

- This skill is designed for COBOL-to-Java/Spring Boot migration projects
- ALL output must be in Markdown format with proper Mermaid diagram syntax
- ALL code examples must be complete, working code (no stubs or placeholders)
- DIAGRAM ACCURACY: Every element must trace to actual COBOL source. Never assume, never invent
- COBOL Source Traceability: Every Java element MUST reference source file + line
- For large projects (50+ programs), process in groups of related modules
- ALWAYS verify Mermaid diagrams render correctly before delivery
- ALWAYS generate `_state-snapshot.json` and `_context-index.md` for projects > 10 COBOL programs
- ALWAYS apply program pattern detection in Phase 5 to speed up analysis
