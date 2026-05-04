# Phase 2: VSAM File Analysis

## Objective

Analyze VSAM file structures, identify AIX (alternate index), GDG (generation data group), and LISTCAT output. Generate JPA Repository mappings.

## Input

- Source files containing SELECT statements for VSAM datasets
- LISTCAT output (if available)
- COPYBOOKs describing VSAM record structures

## Deliverables

### 2.1 `02-vsam-analysis/vsam-data-dictionary.md`

```markdown
# VSAM Data Dictionary

## File Summary

| VSAM File (DDNAME) | ORGANIZATION | Access Mode(s) | RECSIZE | KEY_LEN | KEY_POS | AIX Count | GDG | Repository |
|---------------------|-------------|----------------|---------|---------|---------|-----------|-----|-----------|
| [ddname] | KSDS/ESDS/RRDS | [List modes] | [N] | [N] | [N] | [N] | Y/N | [RepositoryName] |

## Per-File Detail

### File: [DDNAME]
- **DDNAME:** [ddname]
- **DSNAME:** [Full dataset name from SELECT ASSIGN]
- **ORGANIZATION:** KSDS/ESDS/RRDS
- **RECORD LENGTH:** [N]
- **KEY LENGTH:** [N]
- **KEY POSITION:** [N]
- **ACCESS MODES:** [RANDOM / SEQUENTIAL / DYNAMIC]
- **Record Structure:** [COPYBOOK name]
- **VSAM SELECT Statement:** [cobol select text]

## Access Patterns

| Program | File | Operation | VSAM Command | Repository Method |
|---------|------|-----------|-------------|-------------------|
| [name] | [ddname] | READ | CICS READ | findById() |
| [name] | [ddname] | WRITE | CICS WRITE | save() |
| [name] | [ddname] | BROWSE | STARTBR+READNEXT | findAll(Pageable) |

## AIX Analysis (if exists)
| AIX DDNAME | Base File | PATH KEY | INDEXED ON |

## GDG Analysis (if exists)
| GDG Base | Generations | MAXGEN | Usage |
```

### 2.2 ETL Configuration (if mode=full)

Generate `_etl-config.json`:
```json
{
  "vsamFiles": [{
    "ddname": "...",
    "dsname": "...",
    "organization": "KSDS",
    "recordLength": 0,
    "targetTable": "...",
    "targetRepository": "...Repository",
    "fields": [
      {"cobolName": "...", "picClause": "...", "offset": 0, "length": 0, "javaType": "...", "columnName": "..."}
    ]
  }]
}
```

## AIX → Database Index Mapping

| VSAM AIX | PATH KEY | SQL Index |
|----------|----------|-----------|
| AIX name | Path key field(s) | `CREATE INDEX idx_name ON table(path_key_fields)` |

## VSAM Cache Strategy

| Cache Level | Condition | Java |
|-------------|-----------|------|
| L1 (Application) | Read-only reference data | @Cacheable("vsamRef") |
| L2 (DB) | Small tables | JPA 2nd level cache |
| Discard | High-frequency write tables | No cache |

## GDG → Partitioned Storage

| GDG | Strategy | Java |
|-----|----------|------|
| Generation-based | Partition by generation number | PartitionKey = generation |
| Date-based | Use actual date column | PartitionKey = LocalDate |
| Monthly | Monthly partitions | @Shard |

## Execution Steps

### Step 1: Identify VSAM Files

Extract all SELECT/ASSIGN statements from COBOL programs:
- Pattern: `SELECT [ddname] ASSIGN TO [dataset-name]`
- Note ORGANIZATION: INDEXED/SEQUENTIAL/RELATIVE
- Note ACCESS MODE: RANDOM/SEQUENTIAL/DYNAMIC

### Step 2: Extract Access Patterns

For each VSAM file, track:
- Which programs READ it (CICS READ)
- Which programs WRITE/REWRITE it (CICS WRITE/REWRITE)
- Which programs BROWSE it (STARTBR+READNEXT/READPREV)
- Locking: CICS READ UPDATE → PESSIMISTIC_WRITE

### Step 3: Analyze Alternate Index (AIX)

If AIX build JCL or LISTCAT exists:
- Extract DDNAME + BASE CLUSTER
- Extract PATH KEY fields
- Define @Index in JPA Entity

### Step 4: Analyze LISTCAT Output

If LISTCAT output available:
- Extract RECSZ, KEYLEN, KEYPOS
- Extract AIX definitions
- Extract cache/buffer settings

### Step 5: Generate ETL Config

Write `_etl-config.json` with all VSAM-to-RDBMS field mappings:
- Field offset (from COPYBOOK 01 level)
- Field length
- PIC clause → Java type → SQL type
- COMP-3 handling where applicable

### Step 6: Export Data Dictionary

Write `02-vsam-analysis/vsam-data-dictionary.md`

## Quality Gate

- [ ] All VSAM SELECT statements identified
- [ ] Each VSAM file mapped to Repository
- [ ] All access patterns documented
- [ ] AIX indexed (if exists)
- [ ] GDG partitioned (if exists)
- [ ] `_etl-config.json` complete
