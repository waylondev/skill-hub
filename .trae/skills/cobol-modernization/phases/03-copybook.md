# Phase 4: COPYBOOK → JPA Entity Analysis

## Objective

Parse every COPYBOOK file. Extract field definitions, data types, REDEFINES, OCCURS, COMP-3, and 88-level conditions. Generate comprehensive Entity specification.

## Input

- All COPYBOOK files (.cpy)

## Deliverables

### `04-copybook-analysis/copybook-data-structures.md`

Template structure:

```markdown
# COPYBOOK Data Structures

## COPYBOOK Inventory
| # | COPYBOOK | Description | Fields | Used By |
|---|----------|-------------|--------|---------|
| 1 | [name] | [description] | [N] | [program list] |

## Field-Level Analysis (per COPYBOOK)

### [COPYBOOK Name] — [Description]

| Level | Field | PIC | Usage | OCCURS | 88-Level | Java Type | JPA |
|-------|-------|-----|-------|--------|----------|-----------|-----|
| 05 | [name] | [pic] | [usage] | [N] | [enums] | [type] | [annotations] |

## Entity Structure Summary

### Entity: [EntityName] ← [COPYBOOK Name]

| Field (Java) | Type | Mapping Rule | COBOL Source | Column |
|-------------|------|-------------|-------------|--------|
| [name] | [type] | [rule] | [file:line] | [ddl] |
```

### Per-COPYBOOK detail (mandatory):

```markdown
### [COPYBOOK-id]
- **Source:** [filepath]
- **Lines:** [start]-[end]
- **Purpose:** [business description]

**Structure:**
```
[01-level name]
├── 05 [field-name]   PIC [pic]  [usage]   → [Java Type]  [@Annotation]
│   ├── 88 [value-1]  VALUE '[X]'
│   ├── 88 [value-2]  VALUE '[X]'
│   └── 88 [value-3]  VALUE '[X]'
├── 05 [child-field-1] PIC [pic]  [usage]   → [Java Type]
├── 05 [child-field-2] PIC [pic]  OCCURS [n] → List<[Type]>
├── 05 [filler-field]  PIC [pic]             → (FILLER — skip)
└── 05 [redef-field]   REDEFINES [field-name] → [pattern]
```

**Enum Extraction:**
```java
// 88-level → enum
public enum [EnumName] {
    [VALUE_1]("[X]"), [VALUE_2]("[X]"), [VALUE_3]("[X]")
}
```
```

## Execution Steps

### Step 1: Parse COPYBOOK Structure

For each COPYBOOK file:
1. Parse 01-level record structures
2. Analyze level numbers: 01=root, 05-49=child groups, 66=rename, 77=elementary, 88=condition name
3. Extract PIC clause for each field
4. Note USAGE: COMP/COMP-3/COMP-5/DISPLAY/INDEX/POINTER
5. Detect REDEFINES with type discriminator
6. Detect OCCURS (fixed + DEPENDING ON)
7. Detect VALUE clause for 88 conditions
8. Note SIGN clause: LEADING/TRAILING SEPARATE

### Step 2: Map PIC to Java Types

Apply mapping from `references/cobol-to-java-mappings.md`:

| COBOL PIC Pattern | Java Type | JPA Column |
|-------------------|-----------|------------|
| 9(N) where N ≤ 9 | Integer | `INTEGER` |
| 9(N) where N > 9 | Long | `BIGINT` |
| 9(N) leading zeros | String | `VARCHAR(N)` |
| S9(N)V99 (currency) | BigDecimal | `DECIMAL(N+2,2)` |
| S9(N)V9(M) (high precision) | BigDecimal | `DECIMAL(N+M,M)` |
| X(N) YYYYMMDD date | LocalDate | (custom) |
| X(N) DD-MM-YYYY date | LocalDate | (custom) |
| X(N) timestamp | LocalDateTime | (custom) |
| X(N) general text | String | `VARCHAR(N)` |
| X(01) Y/N flag | String | `VARCHAR(1)` |

### Step 3: Handle OCCURS Patterns

| COBOL Pattern | Java | JPA |
|---------------|------|-----|
| `OCCURS 5 TIMES` | `List<Detail>` with pre-allocation | `@ElementCollection` or `@OneToMany(cascade=ALL)` |
| `OCCURS DEPENDING ON COUNT` | `List<Item>` with size validation | `@OneToMany(cascade=ALL, orphanRemoval=true)` |

### Step 4: Handle REDEFINES with Discriminator

REDEFINES patterns:
1. **Type Discriminator:** Field X PIC X(1) discriminates structure → `@Inheritance(strategy=SINGLE_TABLE)` + `@DiscriminatorColumn(name="type", discriminatorType=STRING)`
2. **Alternate views:** Same data viewed differently → Create separate DTO classes, choose based on context flag
3. **Variable lengths:** Use nullable fields in single Entity

### Step 5: Extract Enums from 88-Level

**Rule:** Every contiguous 88-level block under the same field → One Java enum.

| COBOL | Java |
|-------|------|
| 05 STATUS PIC X(1). 88 STATUS-ACTIVE VALUE 'A'. 88 STATUS-INACTIVE VALUE 'I'. | `enum Status { ACTIVE("A"), INACTIVE("I") }` |

### Step 6: Identify Entity Relationships

For COPYBOOKs referenced by multiple VSAM files:
- VSAM file 1 references COPYBOOK A → Entity A
- VSAM file 2 references COPYBOOK A → Entity A (same entity)
- Foreign keys (cross-file references): @ManyToOne, @OneToMany

### Step 7: Handle COPY REPLACING Statements

`COPY COPYBOOK-NAME REPLACING` is a compile-time text substitution. It changes the effective field names/data types before the COPYBOOK content is included in the program.

**Detection Pattern (in .cbl files):**

| COBOL Pattern | Example |
|---------------|---------|
| `COPY CBNAME REPLACING A BY B` | `COPY ACCREC REPLACING ACCT-ID BY CUST-ID` |
| `COPY CBNAME REPLACING ==PRFX== BY ==NEW==` | `COPY ACCREC REPLACING ==WS-== BY ==DB-==` |
| `COPY CBNAME REPLACING LEADING ==X== BY ==Y==` | Prefix replacement |

**Impact on Entity Mapping:**

| REPLACING Scenario | Rule | Java Entity Handling |
|-------------------|------|---------------------|
| Field name substituted | Map substituted name, not original | `// Source: [COPYBOOK], field [original] REPLACED BY [new] in [program]` |
| Same COPYBOOK, different REPLACING across programs | **One COPYBOOK = One Entity**, but document all program-specific name variants | Create a "Field Alias Table" in the analysis output |
| REPLACING changes PIC length (e.g., `==X(10)== BY ==X(20)==`) | Entity uses the **maximum** length from all programs, document as *variable-length* | `@Column(name="field", length=20)` with source note `// REPLACED from PIC X(10) to X(20) in [program]` |

**Analysis Output Requirement:**
For every COPY statement with REPLACING found, append a REPLACING trace table:

```markdown
## COPY REPLACING Registry

| Program | COPYBOOK | Original | Replaced By | Type |
|---------|----------|----------|-------------|------|
| [pgm].cbl | [cb].cpy | ACCT-ID | CUST-ID | FIELD |
| [pgm].cbl | [cb].cpy | WS-ACCT-STATUS | DB-ACCT-STATUS | PREFIX |
```

### Step 8: Export COPYBOOK Analysis

Write `04-copybook-analysis/copybook-data-structures.md` containing:
1. COPYBOOK inventory with usage counts
2. Full field-level analysis per COPYBOOK
3. Entity structure summary (Entity ← COPYBOOK)
4. JAVA ENUM definitions (from 88-level)
5. Java Patterns: REDEFINES / OCCURS strategies
6. Ancestral BMS fields → GraphQL mutation mapping (if GraphQL enabled)
7. Ancestral list screen fields → GraphQL queries (if GraphQL enabled)

## Mandatory Coverage Rules

- **100%:** Every 01/05/elementary field must appear (FILLER = documented but not mapped)
- **88-level:** Document as Java enum with values
- **COMP-3:** Note byte count formula: `(digits+1)/2`
- **Legacy Type Preserved:** Document in _state-snapshot.json before overriding
- **REPLACING:** Every COPY REPLACING statement must be traced back to its COPYBOOK; all substituted names recorded in the REPLACING Registry; PIC length changes from REPLACING must use the maximum across all programs

## Quality Gate (Human Review CP-1)

Before proceeding to Phase 5:
- [ ] Every COPYBOOK fully parsed
- [ ] ALL fields mapped (100% coverage)
- [ ] All REDEFINES patterns identified
- [ ] All OCCURS patterns mapped to Lists
- [ ] All 88-level conditions extracted as Enums
- [ ] All COMP/COMP-3 fields noted
- [ ] All COPY REPLACING statements traced and registered
- [ ] Entity relationships documented
- [ ] DBA review invited at this checkpoint
- [ ] Save `_state-snapshot.json` with {'phase':4,'status':'pending-review'}
