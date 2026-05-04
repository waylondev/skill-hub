# Phase 7: Test Matrix + Golden Test Baseline

## Objective

Build comprehensive test scenarios covering ALL paths identified in programs under analysis. Derive golden test baselines from COBOL behavior and provide traceability across the testing lifecycle.

## Input

- Phase 5 program logic analysis
- Phase 4 COPYBOOK analysis
- Phase 2 VSAM analysis

## Deliverables

### `07-test-matrix/test-matrix.md`

```markdown
# Test Matrix

## Test Strategy Overview
- **Methodology:** Risk-Based Testing with Golden Test Baseline
- **Target Coverage:** >= 80% code paths
- **Testing Levels:** Unit → Integration → Contract → Performance

## Test Scenario Inventory

| ID | Program | Scenario | Priority | Category | Input Data | Expected Behavior | COBOL Reference | Java Test Method |
|----|---------|----------|----------|----------|------------|-------------------|----------------|-----------------|
| TM001 | [pgm] | [description] | Critical | Validation | [sample] | [expected] | line [N] | `[testMethod]` |
| TM002 | [pgm] | [description] | High | [category] | [sample] | [expected] | line [N] | `[testMethod]` |
```

## Test Scenario Priority Classification

| Priority | Criteria | Count |
|----------|----------|-------|
| **Critical** | Financial calculations, security, COBOL SYNCPOINT boundaries | [N] |
| **High** | Core business logic, validation rules, error paths | [N] |
| **Medium** | Edge cases, boundary values, cosmetic logging | [N] |
| **Low** | Dead code handlers, historical maintenance paths | [N] |

## Category Distribution

| Category | Description | Count | Examples |
|----------|-------------|-------|----------|
| Validation | Input validation scenarios | [N] | Empty fields, invalid formats |
| Business Logic | Core transaction processing | [N] | Payment, account inquiry, statement |
| Error Handling | Exception and error scenarios | [N] | Not found, duplicate key, timeout |
| Integration | External system/API scenarios | [N] | MQ, DB2, external CALLs |
| Concurrency | Lock/multi-user scenarios | [N] | Simultaneous updates, race conditions |
| Security | Authentication/authorization | [N] | Wrong password, insufficient role |

## Per-Program Test Detail

### [Program-Name]
- **Program Purpose:** [summary]
- **Entry Points:** [list]
- **Exit Points:** [list]
- **Data Dependencies:** [VSAM files referenced]
- **Integration Dependencies:** [CALL targets]

| # | Path | Trigger | Validation | Computation | Error Handling | Expected Output |
|---|------|---------|------------|-------------|---------------|----------------|
| 1 | Main path | Valid input | Passed | [formula] | None | Success |
| 2 | Error path | Invalid field | Failed | Skipped | [error] | Error message |
```

## Test Scenario Categories

### Validation Scenarios
- Required field blank → @NotBlank validation
- Numeric field non-numeric → @Pattern validation  
- Date field invalid format → DateTimeParseException
- Field length exceeded → @Size validation
- Negative amount → @DecimalMin validation

### Business Logic Scenarios
- Account inquiry with valid ID
- Payment with sufficient balance
- Statement generation for active account
- Interest calculation
- Fee assessment

### Error Handling Scenarios
- Account not found (NOTFND) → 404
- Duplicate key on write → 409
- File I/O error → 500
- Empty file at batch start → skip gracefully

### Concurrency Scenarios (CRITICAL)
- Two users updating same account simultaneously → @Lock(PESSIMISTIC_WRITE) or @Version
- MAX+1 ID generation under load → SEQUENCE test
- Batch job concurrent with online update → Transaction isolation test

## Golden Test Baseline

### Purpose
Compare Java results against known COBOL behavior to validate correctness.

### Baseline Record Format

| ID | Source | Input | COBOL Expected | Java Actual | Match | Notes |
|----|--------|-------|----------------|-------------|-------|-------|
| GB001 | [pgm]:[line] | [input] | [expected] | [actual] | ✅/❌ | [notes] |

### Automated Comparison
```java
@Test
void goldenTest_Tran001() {
    // Source: [program.cbl], lines [N]-[M]
    // COBOL expected output: {amount: 100.00, status: "OK"}
    BigDecimal expectedAmount = new BigDecimal("100.00").setScale(2, HALF_UP);

    BigDecimal actualAmount = service.calculateTotal(input);
    assertThat(expectedAmount).isEqualTo(actualAmount);
}
```

### AI-Derived Golden Baseline (Fallback Strategy)

When a COBOL expert team is NOT available to provide expected outputs, construct the golden baseline from static code analysis alone. This is **inferior** to COBOL-executed baselines but provides coverage for AI-only migration scenarios.

**Applicability:**

| Scenario | Action |
|----------|--------|
| COBOL runtime available, expert available | Use COBOL-executed baselines (preferred) |
| COBOL runtime available, expert NOT available | Run COBOL program with test inputs, capture output |
| COBOL runtime NOT available, expert available | Expert provides expected values from domain knowledge |
| Neither runtime nor expert available | **Use AI-derived fallback (this section)** |

**AI-Derived Baseline Construction (per test scenario):**

| Step | Action | Example |
|------|--------|---------|
| 1. Trace the COMPUTE formula | Extract exact formula from COBOL source | `COMPUTE BALANCE = BALANCE - AMOUNT` → `BigDecimal.subtract()` |
| 2. Identify all input fields and their PIC clauses | Derive type constraints from COPYBOOK | `AMOUNT PIC S9(7)V99` → scale=2, max=9999999.99 |
| 3. Follow all IF/EVALUATE branches | Map conditional logic paths | `IF AMOUNT <= 0` → throw, else proceed |
| 4. Compute expected output manually/bound | Derive from formula + inputs | Input: `BALANCE=500.00, AMOUNT=100.00` → Expected: `400.00` |
| 5. Add confidence marker | Tag with AI-derived confidence | `CONFIDENCE: HIGH/MEDIUM/LOW/UNCERTAIN` |

**Confidence Level Criteria:**

| Confidence | Criteria | Action |
|-----------|----------|--------|
| HIGH | Simple arithmetic with no external CALLs, no COMP-3 input, no REDEFINES overlay | Use as golden baseline directly |
| MEDIUM | Contains COMP-3 fields, simple REDEFINES, or sequential VSAM reads | Accept with bounds-checking assertion (`>= expected * 0.999 AND <= expected * 1.001`) |
| LOW | Contains external CALLs, complex REDEFINES overlays, or COMP-3 writes | Use as **advisory only**, not as hard assertion; add `@Tag("needs-manual-review")` |
| UNCERTAIN | Contains Assembler calls, CICS XCTL chain > 2, or IMS/DB2 embedded SQL | Mark as `GOLDEN_BASELINE_PENDING`, create TODO for human expert |

**AI-Derived Baseline Record Format (extended):**

| ID | Source | Input | Derived Expected | Confidence | Assertion Type | Notes |
|----|--------|-------|-----------------|------------|---------------|-------|
| GB001 | [pgm]:[line] | BALANCE=500,AMT=100 | 400.00 | HIGH | `assertEquals` | Pure subtract, no ext deps |
| GB002 | [pgm]:[line] | ACCT-ID=12345 | Account {balance=...} | MEDIUM | `isCloseTo(expected, within(0.01))` | COMP-3 read involved |
| GB003 | [pgm]:[line] | TXN-ID=999 | Status=APPROVED | LOW | `@Tag("needs-manual-review")` | External CALL to auth system |

```java
// AI-derived golden test with confidence annotation
@Test
@Tag("ai-derived")
@Tag("confidence-medium")
void goldenTest_AiDerived_GB002() {
    // Source: PAYMENT.cbl, lines 234-245, COMPUTE BALANCE = BALANCE - AMOUNT
    // Confidence: MEDIUM — contains COMP-3 balance field
    BigDecimal expected = new BigDecimal("400.00").setScale(2, HALF_UP);
    BigDecimal lowerBound = expected.multiply(new BigDecimal("0.999"));
    BigDecimal upperBound = expected.multiply(new BigDecimal("1.001"));

    BigDecimal actual = service.processPayment(input).getNewBalance();
    assertThat(actual).isBetween(lowerBound, upperBound);
}
```

## Traceability Matrix

Phase 7 establishes the linkage chain:
```
Test Scenario → Program Path → COBOL Source → Java Method → Expected Output
```

## Execution Steps

### Step 1: Extract All Code Paths

From Phase 5 logic analysis:
1. Trace every IF/ELSE branch
2. Trace every EVALUATE WHEN path
3. Trace every PERFORM paragraph entry/exit
4. Trace every SYNCPOINT boundary
5. Document complete path coverage

### Step 2: Classify Test Scenarios

Assign priority to each scenario:
- Financial calculation → Critical
- Security check → Critical
- Core business rule → High
- Field validation → High
- Logging/display → Medium
- Dead code → Low

### Step 3: Define Test Data

For each scenario:
1. Document representative input data
2. Reference specific COBOL source lines
3. Specify expected output (from COBOL behavior or documentation)
4. Define assertion types (equals, matches, contains)

### Step 4: Build Golden Baselines

Select 10-20 high-coverage golden test cases:
1. Cross-check with COBOL team for expected outputs
2. Define precision tolerance (COMP-3: 1e-10)
3. Define rounding strategy (HALF_UP)

### Step 5: Export Test Matrix

Write `07-test-matrix/test-matrix.md`

## Quality Gate (Human Review CP-4)

- [ ] All program entry/exit paths covered
- [ ] All COBOL validations have test scenarios
- [ ] All COBOL error handling has test scenarios
- [ ] Concurrency scenarios explicitly addressed
- [ ] Golden baselines verified with COBOL team
- [ ] QA lead + COBOL developer invited to review CP-4
- [ ] Save `_state-snapshot.json` with {'phase':7,'status':'pending-review'}
