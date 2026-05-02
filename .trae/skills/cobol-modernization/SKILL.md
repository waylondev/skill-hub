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
| batch-size | 8 | COBOL files per batch processing |
| enable-human-review | true | Enable human review checkpoints |
| chunking-strategy | auto | File processing: auto/module-based/rolling |
| mode | lite | Processing mode: lite (core phases) / full (all 20+ phases) |

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
| 8 | Deliverables | [phases/07-deliverables.md](phases/07-deliverables.md) | Entity/Repo/Service/API specifications |
| 9 | Code Generation | [phases/08-codegen.md](phases/08-codegen.md) | AI code generation + golden examples |
| 10+ | Deployment | [phases/09-deployment.md](phases/09-deployment.md) | Frontend, CI/CD, K8s, monitoring, compliance |

## Reference Library

| Document | Content |
|----------|---------|
| [references/cobol-to-java-mappings.md](references/cobol-to-java-mappings.md) | COBOL→Java type/PIC/CICS/JCL mapping tables |
| [references/golden-examples.md](references/golden-examples.md) | Production-grade code examples (Phase 9.5 standard) |
| [references/quality-checklist.md](references/quality-checklist.md) | QA mandatory checks + delivery checklist + pitfalls |
| [references/production-patterns.md](references/production-patterns.md) | Migration strategies + deployment patterns |

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
│   └── copybook-data-structures.md
├── 05-program-logic/
│   └── program-logic-analysis.md
├── 06-architecture/
│   ├── architecture-diagrams.md
│   └── scheduler-mapping.md          # [IF scheduler exists]
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
│   └── security-mapping.md
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
| `lite` | Core phases 1-9 | Core analysis + entity specs + service guides | Small projects < 50 COBOL programs, quick assessments |
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

## Notes

- This skill is designed for COBOL-to-Java/Spring Boot migration projects
- ALL output must be in Markdown format with proper Mermaid diagram syntax
- ALL code examples must be complete, working code (no stubs or placeholders)
- DIAGRAM ACCURACY: Every element must trace to actual COBOL source. Never assume, never invent
- COBOL Source Traceability: Every Java element MUST reference source file + line
- For large projects (50+ programs), process in groups of related modules
- ALWAYS verify Mermaid diagrams render correctly before delivery
