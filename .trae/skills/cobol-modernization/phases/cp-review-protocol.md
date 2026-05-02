# Human Review Checkpoint Protocol

> **CRITICAL:** This protocol MUST be followed at EVERY checkpoint (CP-1 through CP-5).

## Overview

Human review checkpoints are **mandatory pauses** in the analysis-to-code-generation pipeline. They prevent AI-driven inaccuracies from propagating into production code. Each checkpoint focuses on a specific set of deliverables and involves specific human reviewers.

## Checkpoint Summary

| Checkpoint | After Phase | Review Focus | Who | Duration (est.) |
|-----------|-------------|--------------|-----|----------------|
| **CP-1** | Phase 4 (COPYBOOK) | Entity relationships, field mappings, COMP-3 handling | DBA + COBOL developer | 30 min |
| **CP-2** | Phase 5 (Program Logic) | Computation formulas, validation rules, edge cases | Business analyst + COBOL developer | 60 min |
| **CP-3** | Phase 6 (Architecture) | Service boundaries, module dependencies, protocols | Solution architect | 45 min |
| **CP-4** | Phase 7 (Test Matrix) | Test scenarios coverage, golden test baselines | QA lead + COBOL developer | 45 min |
| **CP-5** | Phase 8 (Deliverables) | Java code completeness, pattern correctness | Java developer + architect | 60 min |

## AI Execution Protocol at Each Checkpoint

### STEP 1: Generate Review Package

For the current checkpoint, produce a **Review Summary Document** at `_review-log.md`:

```markdown
# Review Log — CP-[N]: [Phase Name] Review

## Date: YYYY-MM-DD
## Output Documents Under Review:
- [list of files in this phase]

## Review Checklist

### Section 1: Structure Completeness
[ ] [check item 1]
[ ] [check item 2]
...

### Section 2: Data Accuracy
[ ] [check item 1]
...

### Section 3: Mapping Correctness
[ ] [check item 1]
...

## Items Requiring Special Attention
| Item | Concern Level | What to Verify | Source |
|------|-------------|----------------|--------|

## Known Questions for Reviewers
1. [specific question]
2. [specific question]

---
**Review Status:** [ ] PASS / [ ] NEEDS REVISION
**Reviewer Name:** _____________
**Date/Time:** _____________
**Sign-off:** _____________
```

### STEP 2: Pause and Request Review

**TRIGGER PHRASE (exact text, sent to user):**

```
============================================
🔴 HUMAN REVIEW CHECKPOINT CP-[N]: [Phase Name]
============================================

Review Package: `_review-log.md` (section CP-[N])
Documents Under Review:
  - [doc1 path]
  - [doc2 path]

📋 **Reviewer(s):** [role1] + [role2]
⏱️ **Estimated Review Time:** [duration]

Please review the following items:

1. [key review item 1]
2. [key review item 2]
3. [key review item 3]

**After review, reply:** "CP-[N] PASS" to continue, or describe issues to fix.
============================================
```

### STEP 3: Wait for User Confirmation

DO NOT proceed past the checkpoint until user explicitly responds with:
- `"CP-[N] PASS"` → proceed to next phase
- `"CP-[N] REVISE: [description]"` → re-run relevant phase, re-present for review

### STEP 4: Document Decision

Log ALL feedback in `_review-log.md`. Update `_state-snapshot.json` with checkpoint status.

## Per-Checkpoint Detailed Checklists

### CP-1: COPYBOOK → Entity Mapping (After Phase 4)

| # | Verification Item | How to Verify |
|---|-----------------|---------------|
| 1 | All COPYBOOK fields present in entity mapping | Count .cpy fields vs entity fields |
| 2 | COMP-3 fields correctly identified with hex examples | Check vsam-data-formats.md |
| 3 | 88-level values match source COPYBOOK | Compare VALUE clauses |
| 4 | REDEFINES properly documented with dual-use strategy | Check REDEFINES section |
| 5 | OCCURS count matches source | Count OCCURS vs Java List annotations |
| 6 | FILLER fields documented as reserved | Check for undocumented FILLER |
| 7 | PIC precision preserved in JPA @Column(precision, scale) | Verify S9(N)V99 mappings |
| 8 | Field names follow Java camelCase convention | Spot-check 10 fields |
| 9 | CommArea structure matches COCOM01Y.cpy | Verify all CDMA-* fields |
| 10 | Sub-application COPYBOOKs also analyzed | Count sub-app .cpy files |

### CP-2: Logic Analysis → Service Specs (After Phase 5)

| # | Verification Item | How to Verify |
|---|-----------------|---------------|
| 1 | EVERY program has complete paragraph inventory | Count program count × expected sections |
| 2 | All IF/EVALUATE branches documented with line numbers | Grep source vs documented count |
| 3 | COMPUTE formulas correctly translated | Formula-to-Java method mapping review |
| 4 | State machines have ALL transitions documented | Review FSM diagram completeness |
| 5 | Business rules extracted with source lines | Rule count × traceability |
| 6 | PF key behaviors correctly mapped | ERASE/CLEAR vs PF3 behavior review |
| 7 | CICS RESP handling mapped to Java exceptions | RESP code table review |
| 8 | MQ commands documented for sub-application programs | MQGET/MQPUT count |
| 9 | DB2 SQL operations documented | EXEC SQL count vs documented |
| 10 | Assembler calls documented with replacement strategy | ASM program count vs documented |

### CP-3: Architecture Reviews (After Phase 6)

| # | Verification Item | How to Verify |
|---|-----------------|---------------|
| 1 | Every COBOL program assigned to exactly one service | Cross-reference inventory |
| 2 | Service boundaries align with business domains | Domain alignment review |
| 3 | Inter-service protocols correctly specified | REST vs MQ vs Event review |
| 4 | Batch dependencies correctly mapped | JCL step sequence vs diagram |
| 5 | Security architecture covers ALL access patterns | RACF to Spring Security mapping |
| 6 | Database shared vs per-service decision documented | DB topology diagram |
| 7 | Circuit breaker thresholds realistic | Timeout values review |
| 8 | API Gateway routes match Phase 8 endpoints | Route count comparison |

### CP-4: Test Matrix Review (After Phase 7)

| # | Verification Item | How to Verify |
|---|-----------------|---------------|
| 1 | ≥ 3 test cases per COBOL program | Test-per-program count |
| 2 | Edge case coverage for ALL COBOL IF branches | IF branch count vs test count |
| 3 | Batch program test coverage | Batch test case count ≥ 5 each |
| 4 | Golden test baseline accuracy | Compare with ASCII test data |
| 5 | Sub-application test coverage | Auth + DB2 test case count |
| 6 | Error handling test cases | RESP code coverage |
| 7 | Pagination boundary tests | Max/min page size tests |
| 8 | Concurrent modification test scenarios | REWRITE conflict scenarios |

### CP-5: Code Generation Gate (After Phase 8)

| # | Verification Item | How to Verify |
|---|-----------------|---------------|
| 1 | All Entity classes have complete @Column annotations | Field annotation coverage |
| 2 | All Repository interfaces have cursor-based pagination | findAfter/findBefore count |
| 3 | All Service classes use constructor injection | Grep for @Autowired field → should be 0 |
| 4 | All DTO Request classes have Bean Validation | @Valid/@NotNull/@Size coverage |
| 5 | Exception hierarchy covers ALL COBOL RESP codes | Exception-to-RESP mapping table |
| 6 | GlobalExceptionHandler has ALL exception mappings | @ExceptionHandler count |
| 7 | OpenAPI 3.0 spec validates | Swagger Editor validation |
| 8 | Flyway scripts are executable SQL | Syntax check on PostgreSQL |
| 9 | ALL code has `// Source:` reference comments | Source comment coverage ≥ 90% |
| 10 | No TODO/placeholder/fixme in generated code | Grep for TODO/FIXME |

## Handling REVIEW FAILURES

If reviewer indicates issues at any CP:

1. **Log** the specific issue in `_review-log.md`
2. **Re-execute** the relevant phase with the corrected understanding
3. **Re-present** the CP review package with changes highlighted
4. **Update** `_context-index.md` with revision notes
5. **Do NOT skip** — wait for explicit PASS again

## State Management

After each CP, update `_state-snapshot.json`:

```json
{
  "review-checkpoints": {
    "CP-1": "passed",
    "CP-2": "passed",
    "CP-3": "pending",
    "CP-4": "pending",
    "CP-5": "pending"
  },
  "last-cp-action": "CP-2 passed by [reviewer] at [timestamp]"
}
```
