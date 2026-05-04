---
name: cobol-modernization
description: Complete COBOL-to-Java migration framework with portfolio assessment, code analysis, documentation generation, testing matrix, and production migration strategies. Invoke when analyzing COBOL legacy systems, planning COBOL modernization projects, or migrating COBOL/CICS/VSAM to Java Spring Boot.
---

# COBOL Modernization Skill

## Quick Start

```
User intent                      → Execute phases
──────────────────────────────────────────────────
"分析这个COBOL项目"               → ALL Core Phases (1-9)
"分析代码逻辑"                    → Phase 1 + Phase 5
"生成迁移文档"                    → Core Phases (1-9)
"生成Java代码"                    → Core Phases + Code Generation (9)
"完整迁移到生产"                  → ALL phases including extended (10+)
```

## Configuration Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| target-db | postgresql | Target database: postgresql/mysql/oracle |
| spring-boot-version | 3.3.x | Spring Boot version (LTS) |
| java-version | 21 | Java version (LTS) |
| mq-provider | jms | Message queue provider: jms/rabbitmq/kafka |
| mode | lite | Processing: lite (phases 1-9) / full (phases 1-20) |
| batch-size | 8 | COBOL files per batch processing |
| enable-human-review | true | Enable review checkpoints CP-1 to CP-5 |
| include-flyway | true | Include Flyway database migration scripts |
| include-sub-applications | auto | Analyze optional sub-app modules |
| diagram-style | modern | Mermaid diagram style: modern/standard/minimal |
| output-format | markdown | Output format: markdown/confluence/html |

## Execution Flow

### Stage 1: Analysis (Phases 1-7)

Parse source code, extract structures, identify dependencies, build test matrix.

```
Phase 1 (Discovery)     → File inventory + complexity scoring
Phase 2 (VSAM)          → Data dictionary + JPA Repository mapping
Phase 3 (BMS)           → Screen specs + REST API mapping
Phase 4 (COPYBOOK)      → Data structures → JPA Entity mapping    → CP-1 Review
Phase 5 (Logic)         → Business logic → Service mapping        → CP-2 Review
Phase 6 (Architecture)  → Dependency graph + microservice split    → CP-3 Review
Phase 7 (Test Matrix)   → Test scenarios + golden baseline         → CP-4 Review
```

**After Stage 1:** Pause and prompt user: "Analysis complete. Review documents in 00-07 directories. Reply 'continue' to start code generation."

### Stage 2: Generation (Phases 8-9)

Generate complete Java code using Stage 1 analysis documents as context (NOT original COBOL source).

```
Phase 8 (Deliverables)  → Entity/Repository/Service/DTO/Controller specs
Phase 9 (Code Generation) → Complete, compilable Java code          → CP-5 Review
```

### Stage 3: Extended (Phases 10+, mode=full only)

```
Phase 10a-g  → DTO/Flyway/OpenAPI/Security/Batch/MQ/Data sub-deliverables
Phase 11     → AI code generation from Phase 8-10 specs
Phase 12+    → Frontend, CI/CD, K8s, compliance, benchmarking
```

## Core Rules

1. **NEVER skip source files** — Every .cbl/.cpy/.bms/.jcl must be analyzed
2. **NEVER use placeholder text** — All output must contain actual extracted data
3. **ALWAYS trace to source** — Every Java element references `// Source: [filename], line [N]`
4. **ALWAYS generate complete code** — No stubs, no pseudocode, no TODOs
5. **ALWAYS follow directory structure** — See Output Directory Structure below
6. **ALWAYS preserve COBOL semantics** — Fixed-width fields, PIC precision, COMP-3 packing
7. **ALWAYS verify written files** — Read back generated files to confirm completeness
8. **NEVER single-session large projects** — Use phased execution with state management
9. **ALWAYS pause at checkpoints** — Wait for user confirmation at CP-1 through CP-5
10. **ALWAYS analyze PROCEDURE DIVISION** — No program may be skipped; if context limit, save state and resume

## Output Directory Structure

```
project-name/
├── 00-portfolio/              # Portfolio assessment
├── 01-source-inventory/       # File inventory
├── 02-vsam-analysis/          # VSAM data dictionary
├── 03-bms-analysis/           # BMS screen specs
├── 04-copybook-analysis/      # COPYBOOK → Entity mapping
├── 05-program-logic/          # Business logic analysis
├── 06-architecture/           # Architecture diagrams
├── 07-test-matrix/            # Test scenarios
├── 08-deliverables/           # Complete Java specifications
├── 09-database-migrations/    # Flyway scripts
└── 10-cicd-pipeline/          # CI/CD + deployment (full mode)
```

## Input Validation (Step 0)

Before any analysis, verify:
- Source directory path provided and exists
- At least one .cbl or .cpy file found
- Files are readable

If checks fail, prompt user with specific error message.

## Phase References

See `phases/` directory for detailed phase specifications:

| # | Phase | File | Purpose |
|---|-------|------|---------|
| 1 | Discovery | `phases/01-discovery.md` | Scan & classify source files |
| 2 | VSAM | `phases/02-vsam.md` | VSAM → JPA Repository mapping |
| 3 | BMS | `phases/03-screens.md` | BMS Map → REST API mapping |
| 4 | COPYBOOK | `phases/04-copybook.md` | Data structure → JPA Entity mapping |
| 5 | Logic | `phases/05-logic.md` | Business logic → Service implementation |
| 6 | Architecture | `phases/06-architecture.md` | Dependency graph + microservice split |
| 7 | Testing | `phases/07-testing.md` | Test matrix + golden baseline |
| 8 | Deliverables | `phases/08-deliverables.md` | Complete Java specifications |
| 9 | Code Gen | `phases/09-codegen.md` | AI code generation |
| 10+ | Extended | `phases/10-deployment.md` | Frontend, CI/CD, K8s, compliance |

### Phase 8 Sub-Deliverables (8a-8g)

Phase 8 generates core specs (8.1-8.12). Extended sub-deliverables are generated in Phases 10a-10g:

| Sub | Deliverable | Phase File |
|-----|------------|------------|
| 8.1-8.12 | Core Java specs (Entity/Repo/Service/DTO/API/Exception/Enum/Batch/Rules/Security/Flyway/OpenAPI) | `phases/08-deliverables.md` |
| 10a | DTO & Validation (complete DTO classes) | `phases/10-dto-specification.md` |
| 10b | Flyway Migrations (V1+V2+V3 SQL) | `phases/11-flyway-migration.md` |
| 10c | OpenAPI 3.0 YAML spec | `phases/12-openapi.md` |
| 10d | Security Audit report | `phases/13-security-audit.md` |
| 10e | Batch Dependency DAG | `phases/14-batch-deps.md` |
| 10f | MQ Message Catalog | `phases/15-mq-catalog.md` |
| 10g | Data Model Merge (IMS/DB2/VSAM) | `phases/16-data-model-merge.md` |

## Reference Library

| Document | Content |
|----------|---------|
| `references/cobol-to-java-mappings.md` | COBOL→Java type/PIC/CICS/JCL mapping tables |
| `references/golden-examples.md` | Production-grade code examples (Phase 9 standard) |
| `references/quality-checklist.md` | QA mandatory checks (68 checks) + delivery checklist |
| `references/production-patterns.md` | Migration strategies + deployment patterns |
| `references/troubleshooting.md` | Common issues, recovery protocols, debugging guides |
| `references/assembler-replacement.md` | Assembler utility → Java replacement patterns |
| `references/complex-copybook-guide.md` | REDEFINES, OCCURS, COPY REPLACING advanced patterns |

## Human Review Checkpoints

| Checkpoint | After Phase | Review Focus | Who |
|-----------|-------------|--------------|-----|
| CP-1 | Phase 4 | Entity relationships, field mappings | DBA + COBOL developer |
| CP-2 | Phase 5 | Formulas, validation rules, edge cases | Business analyst + COBOL developer |
| CP-3 | Phase 6 | Service boundaries, dependencies | Solution architect |
| CP-4 | Phase 7 | Test coverage, golden baselines | QA lead + COBOL developer |
| CP-5 | Phase 9 | Java completeness, patterns | Java developer + architect |

## Session State Management

For projects >10 COBOL programs, maintain state files:

| File | Purpose |
|------|---------|
| `_state-snapshot.json` | Current phase, batch progress, review status |
| `_context-index.md` | Files processed per batch |
| `_kb-reference.md` | Compact knowledge base for Stage 2 |
| `_review-log.md` | Human review feedback and decisions |

**Resume Protocol:**
1. Read `_state-snapshot.json` for last completed phase
2. Read `_context-index.md` for processed files
3. Skip completed work, process only pending items

## Language Policy

- **User-facing documentation**: Match user's input language
- **Technical deliverables** (code, SQL, config): English
- **File/directory names**: English, kebab-case
- **Code comments**: English, with COBOL source reference format

## Exception Handling

| Feature Not Found | Action |
|-------------------|--------|
| No DB2 code (no EXEC SQL) | Skip DB2 analysis |
| No IMS code (no EXEC DLI) | Skip IMS analysis |
| No MQ code (no MQGET/MQPUT) | Skip MQ analysis |
| No BMS files | Skip BMS→REST mapping |
| No JCL files | Skip JCL→Batch mapping |
| No COMP-3 fields | Skip COMP-3 section |

## Precision Standards

Every phase output is evaluated against precision requirements. Key standards:

| Deliverable | Minimum Precision |
|-------------|------------------|
| Entity Specification | Complete class code with ALL fields, annotations, business methods |
| Repository | Complete interface with ALL methods, @Lock, @Query, Pageable |
| Service | Complete class with ALL methods, constructor injection, @Transactional |
| DTO | Complete Request/Response with Bean Validation from COBOL IF rules |
| Flyway Scripts | Complete V1+V2+V3: all tables, FKs, indexes, seed data |
| Test Matrix | ≥3 test cases per program with golden baseline |

## Cross-Validation Rules

After Phase 8, verify consistency across all documents:

1. **Entity-VSAM**: Every Entity field matches VSAM/COPYBOOK — no invented fields
2. **BMS-DTO**: Every UNPROT field → Request DTO; every PROT field → Response DTO
3. **Program-Service**: Every COBOL program has a corresponding Service class
4. **Repository-IO**: Every VSAM READ/WRITE has a Repository method
5. **API-Screen**: Every BMS screen has at least one REST endpoint
6. **Exception-Error**: Every error condition has exception type + HTTP status

## Context Window Management

### Token Budget Guidelines

| Scenario | Approximate Tokens | Strategy |
|----------|-------------------|----------|
| Small project (<10 .cbl files) | ~15K-30K | Single session OK |
| Medium project (10-50 .cbl) | ~50K-150K | Phase-based execution with checkpoints |
| Large project (50+ .cbl) | ~200K+ | Module-based chunking, state files mandatory |

### Loading Strategy

| Phase | Load Full | Load Compact | Process |
|-------|-----------|-------------|---------|
| 1-4 | Source files being analyzed | SKILL.md + current phase doc | Read only relevant .cbl/.cpy files |
| 5 (Logic) | One .cbl at a time | `_kb-reference.md` + mappings | NEVER load all .cbl at once |
| 6-7 | Phase 1-5 summaries | `_context-index.md` | Summarize, don't load full docs |
| 8-9 | One deliverable at a time | `_kb-reference.md` + golden examples | Generate from analysis docs only |

## Getting Started (First-Time Use)

1. **Prepare your COBOL source directory** — Ensure all .cbl/.cpy/.bms/.jcl files are in one directory
2. **Invoke the skill** — Provide the source directory path
3. **Stage 1 runs** — The skill analyzes all files through Phase 7
4. **Review at checkpoints** — At CP-1 through CP-4, review generated documents
5. **Say "continue"** — Stage 2 generates complete Java specifications (Phase 8-9)
6. **Review CP-5** — Verify Java code completeness
7. **(Optional) Mode=full** — Extended phases for CI/CD, deployment, compliance

Example:
```
User: "分析这个COBOL项目: C:\projects\legacy-bank-cobol\source"
→ Skill runs Phases 1-7, pauses at CP-1
User: "继续" (or "continue")
→ Skill resumes Stage 2, generates Phase 8-9
```
