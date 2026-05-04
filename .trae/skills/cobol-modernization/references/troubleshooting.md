# Troubleshooting Guide for COBOL Modernization

## Context Window Overflow

| Symptom | Cause | Solution |
|---------|-------|----------|
| Analysis stops mid-program | Token limit reached | Save state in `_state-snapshot.json`, resume with "continue from Phase [N]" |
| Output truncated mid-section | Single response too large | Split into multiple files (part1.md, part2.md, etc.) |
| AI forgets earlier programs | Context window full | Load `_kb-reference.md` instead of full documents; process one program at a time |

### Recovery Protocol
1. Check `_state-snapshot.json` for last completed phase and batch
2. Read `_context-index.md` to identify already-processed files
3. Resume from next pending item only
4. Append new analysis to existing deliverable (do NOT overwrite)

## Incomplete File Analysis

| Problem | Detection | Fix |
|---------|-----------|-----|
| Program missing from analysis | Count .cbl files vs Phase 5 program count | Re-run Phase 5 for missing programs |
| COPYBOOK fields not mapped | Count fields in .cpy vs Entity field count | Re-analyze the specific COPYBOOK |
| BMS map skipped | Count .bms files vs Phase 3 map count | Re-run Phase 3 for missing maps |
| VSAM file not mapped | Check SELECT statements vs data dictionary | Cross-reference Phase 2 with source |

## Cross-Validation Failures

| Check | Failure Symptom | Root Cause | Fix |
|-------|----------------|------------|-----|
| Entity-VSAM | Entity has extra fields | AI invented fields | Remove unmatched fields, re-trace to COPYBOOK |
| BMS-DTO | UNPROT field missing from DTO | Incomplete BMS analysis | Re-extract field from .bms, add to DTO |
| Program-Service | No Service for a program | Phase 5 skipped program | Analyze missing program, generate Service |
| Repository-IO | VSAM operation with no Repository method | Phase 2 incomplete | Add method matching VSAM access pattern |
| API-Screen | BMS map with no endpoint | Phase 8 mapping gap | Create GET/POST endpoints for the screen |
| Exception-Error | Error condition without exception | Phase 5 error handling missed | Add exception class + HTTP status mapping |

## Common COBOL Parsing Issues

| Issue | How to Detect | Resolution |
|-------|--------------|------------|
| COPY REPLACING not applied | Field name in Entity matches original COPYBOOK | Search .cbl for `REPLACING`, apply substituted name |
| COMP-3 byte count wrong | Unpack method uses wrong byte count | Verify formula: `(total_digits + 1) / 2` |
| REDEFINES overlap not handled | Same memory area mapped to two Entity fields | Use @Inheritance or separate DTOs with discriminator |
| OCCURS count ignored | Single field instead of List<Entity> | Check for OCCURS clause, convert to List<T> |
| 88-level values merged into wrong enum | Enums have mixed purposes | Group 88-levels by their parent field |
| PIC 9(N)V99 → double instead of BigDecimal | Loss of precision risk | ALWAYS use BigDecimal with explicit precision/scale |
| Date format mismatch | X(08) YYYYMMDD parsed as String | Apply `DateTimeFormatter.ofPattern("yyyyMMdd")` |

## Large Project Strategy (50+ Programs)

| Scenario | Strategy |
|----------|----------|
| Project > 50 .cbl files | Use module-based chunking (batch-size=8 default) |
| Multiple sub-applications | Process main app first, then sub-apps by dependency order |
| Mixed COBOL/DB2/IMS/MQ | Separate analysis paths: COBOL→VSAM→BMS, then DB2, then IMS, then MQ |
| Resume after interruption | Read `_state-snapshot.json`, skip completed batches |
| Context budget tight | Load `_kb-reference.md` (compact) instead of full analysis documents |

## Quality Degradation Signs

| Sign | Meaning | Action |
|------|---------|--------|
| Generic descriptions replacing actual data | AI summarizing instead of extracting | Re-run phase with "extract actual data, no summaries" prompt |
| Missing source line references | Traceability lost | Regenerate with mandatory `// Source: [file], line [N]` rule |
| TODO/placeholder comments in code | Incomplete generation | Regenerate with "complete code only, no stubs" constraint |
| Mermaid diagrams fail to render | Syntax errors | Validate diagram syntax in Mermaid Live Editor |

## Phase-Specific Recovery

| Phase | If Failed | Recovery Steps |
|-------|-----------|---------------|
| Phase 1 | Files not inventoried | Re-scan source directory, count by extension |
| Phase 2 | VSAM not mapped | Extract SELECT/ASSIGN from .cbl, map to COPYBOOK |
| Phase 3 | BMS not analyzed | Parse DFHMDF fields from .bms, classify UNPROT/PROT |
| Phase 4 | COPYBOOK incomplete | Re-parse 01-level structure, extract ALL fields |
| Phase 5 | Program logic missing | Read PROCEDURE DIVISION of missing program |
| Phase 6 | Architecture diagram broken | Verify Mermaid syntax, check all nodes exist |
| Phase 7 | Test matrix sparse | Re-trace IF/EVALUATE branches from Phase 5 |
| Phase 8 | Specs incomplete | Re-read Stage 1 docs, regenerate missing specs |
