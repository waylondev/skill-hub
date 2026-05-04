# Phase 1: Source File Discovery & Classification

## Objective

Scan provided source directory. Classify every file by type, extract key metadata, and build portfolio assessment and source inventory.

## Input

- Source directory containing .cbl, .cpy, .bms, .jcl, .prc, .mac, .controlm, .ca7 files

## Deliverables

### 1.1 `00-portfolio/portfolio-assessment.md`

**Template:**

```markdown
# Portfolio Assessment

## Application Overview
- **Application Name:** [Extracted from source or directory name]
- **Module/Component:** [Component name from source]
- **Total Files Analyzed:** [count]
- **Assessment Date:** [date]

## Asset Inventory

| Asset Type | Count | Description |
|------------|-------|------------|
| COBOL (.cbl) | [N] | Programs |
| COPYBOOK (.cpy) | [N] | COPYBOOK includes |
| BMS Maps (.bms) | [N] | BMS maps |
| JCL (.jcl) | [N] | Job Control |
| PROC (.prc) | [N] | JCL PROCs |
| PARM (.parmlib) | [N] | Parameter files |
| Total | [sum] | |

## Module Distribution

| Category | Count | Description |
|----------|-------|------------|
| Online/CICS Programs | [N] | Transaction processing |
| Batch Programs | [N] | Batch processing |
| DB2 Programs | [N] | Database programs |
| IMS Programs | [N] | IMS programs |
| Subprograms | [N] | Utility/SUBPROGRAM |

## Complexity Assessment

| Metric | Value | Risk Level |
|--------|-------|-----------|
| Total Lines of Code | [N] | [Low/Med/High] |
| Average Program Size (LOC) | [N] | [Low/Med/High] |
| Number of COPYBOOK Dependencies | [N] | [Low/Med/High] |
| Number of External CALLs | [N] | [Low/Med/High] |
| Number of I/O Operations | [N] | [Low/Med/High] |
| COMP-3 Operations Count | [N] | [Low/Med/High] |

## Program Migration Priority

| Program | LOC | I/O Ops | Dependencies | Score | Priority | Wave |
|---------|-----|---------|-------------|-------|----------|------|
| [name] | [n] | [n] | [n] | [score] | [priority] | [wave] |

## Dead Code Candidates
| File | Reason | Confidence |
|------|--------|-----------|
| [file] | [reason] | High/Med/Low |

## First-Principles Analysis
- [Key architectural findings]
- [Data flow patterns discovered]
- [Integration points identified]

## Migration Strategy Recommendation
- **Approach:** 5R Assessment (Retire|Retain|Rehost|Refactor|Rewrite)
- **Recommended Architecture:** [Monolithic / Modular Monolith / Microservices]
```

### 1.2 `01-source-inventory/source-file-inventory.md`

**Template:**

```markdown
# Source File Inventory

## Discovery Directory
[absolute path on disk]

## File Classification Matrix

| # | File Name | Type | Category | LOC | COPYBOOKs Used | External CALLs | Description |
|---|-----------|------|----------|-----|----------------|----------------|------------|
| 1 | [name.cbl] | COBOL | Online | [n] | [list] | [list] | [summary] |
| 2 | [name.cpy] | COPYBOOK | Data | [n] | n/a | n/a | [data structure] |
| 3 | [name.bms] | BMS | Screen | [n] | n/a | n/a | [screen name] |
| 4 | [name.jcl] | JCL | Batch | [n] | n/a | n/a | [job name] |
```

## Execution Steps

### Step 1: Scan Source Directory

Systematically scan the provided directory:
1. Identify ALL files with extensions: .cbl, .cpy, .bms, .jcl, .prc, .mac, .controlm, .ca7, .listcat, .racf, .parmlib
2. Count files per type
3. Compute total Lines of Code (LOC) per file
4. For large projects (50+ .cbl files), identify natural module groupings

### Step 2: Classify COBOL Programs

For each .cbl file, classify by examining content:

| Detection Pattern | Classification |
|-------------------|---------------|
| Contains `EXEC CICS` statements | **CICS Online Program** |
| Contains `SELECT filename ASSIGN TO` + no EXEC CICS | **Batch Program** |
| Contains `EXEC SQL` statements | **DB2 Program** |
| `PROCEDURE DIVISION USING ...` with no EXEC CICS | **Subprogram** |
| Contains `CBL` compiler directives | **Note compiler flags** |

### Step 3: Extract Dependency Graph (Summary)

For each COBOL program, extract:
1. COPYBOOK includes: `COPY COPYBOOK-ID` or `INCLUDE COPYBOOK-ID`
2. Program CALLs: `CALL 'PROGRAM-NAME' USING ...`
3. Data file references: `SELECT filename ASSIGN TO`

### Step 4: Compute Complexity Metrics

Use the portfolio scoring formula from `references/quality-checklist.md`:

```
Score = (LOC/100 × 1) + (I/O_ops × 3) + (deps × 2) + (branches/5 × 1) + (COMPUTEs × 2) + (CICS_cmds × 2) + (COMP3_fields × 3) + (BMS_fields/10 × 1)
```

### Step 5: Identify Dead Code

Mark as dead code if ANY of:
- Program never referenced in JCL or program calls
- COPYBOOK never included by any program
- Commented-out sections > 40% of file
- File contains `* * * * HISTORICAL * * * *` markers

### Step 6: Export Portfolio

Write `00-portfolio/portfolio-assessment.md` with:
- Complete asset inventory
- Classification tables
- Complexity scores and risk levels
- Migration priority with wave assignments

### Step 7: Export Source Inventory

Write `01-source-inventory/source-file-inventory.md` with:
- Complete file listing
- Per-file metadata (LOC, dependencies, type)
- Classification matrix

## Quality Gate (before proceeding to Phase 2)

- [ ] Every .cbl file classified
- [ ] Every COPYBOOK dependency mapped
- [ ] All external CALLs documented
- [ ] Migration priority scores computed
- [ ] Dead code candidates identified
