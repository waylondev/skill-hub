# CHANGELOG

## v2.0 (2026-05-04) — Production Hardening Release

### Added
- **Phase 10-20 Independent Documents**: Split merged `10-deployment.md` into 11 individual Phase documents (10-frontend-migration.md through 20-performance-benchmarking.md) for clear execution guidance
- **Phase 18** (Data Migration Strategy): Complete document covering ETL pipeline, validation rules, rollback SOP, dual-write reconciliation
- **Phase 19** (Regression Testing Automation): Complete document covering test framework selection, CI/CD orchestration, test data management
- **Before You Start** section: Prerequisites and preparation checklist in SKILL.md
- **Known Limitations & Roadmap** section: Capability boundaries and planned enhancements in SKILL.md
- **7 New Reference Documents**:
  - `cobol-intrinsic-functions.md` — 50+ COBOL intrinsic function → Java mappings
  - `racf-spring-security-mapping.md` — RACF → Spring Security detailed mapping
  - `ebcdic-conversion-toolchain.md` — EBCDIC encoding conversion toolchain guide
  - `performance-sla-templates.md` — OLTP & Batch performance SLA templates
  - `observability-standards.md` — Metrics/Logging/Tracing observability standards
  - `security-scanning-integration.md` — SAST/DAST security scanning CI integration
  - `i18n-l10n-strategy.md` — COBOL message internationalization strategy
- **CHANGELOG.md**: Version history tracking

### Fixed
- SKILL.md Phase References table now includes `cp-review-protocol.md`
- Sub-phase naming unified: `10a-10g` → `Phase 10-16`
- All placeholder values `[N]`/`[$]`/`[provider]` replaced with calculation formulas
- quality-checklist.md external references updated to point to actual existing files
- Missing Phase 18-19 content gaps filled

### Removed
- `phases/10-deployment.md` (merged doc replaced by 11 independent Phase files)

---

## v1.0 (Initial Release)
- Core Phase 1-9 documents for COBOL-to-Java migration
- 5 Human Review Checkpoints (CP-1 through CP-5)
- 68 QA Mandatory Checks
- Golden Code Examples (4 production scenarios)
- Session State Management (4 state files + Resume Protocol)
- Reference: cobol-to-java-mappings.md, golden-examples.md, quality-checklist.md, production-patterns.md
- Phase 8 Sub-Deliverables (8.1-8.12 Java spec generation)
- Troubleshooting Guide (8 categories)
- Assembler Replacement Guide
- Complex COPYBOOK Handling Guide
