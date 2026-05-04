# Phase 18: Data Migration Strategy

## Objective

Define and execute a comprehensive data migration strategy to move all VSAM and DB2 data from the mainframe into PostgreSQL. The strategy must ensure zero data loss, verifiable integrity, minimal production downtime, and a tested rollback path. Supports both "big bang" cutover and phased dual-write approaches.

## Input

- Phase 2: VSAM Analysis — file metadata, record counts, key structures, data volumes
- Phase 4: COPYBOOK Analysis — field-level encoding, COMP-3 usage, EBCDIC code pages
- Phase 5: Logic Extraction — all data access patterns (READ/WRITE/UPDATE/DELETE paths)
- Phase 9: Generated Code (Flyway migration scripts, Entity definitions)
- Phase 13: Docker & Kubernetes (target database connection strings)
- Phase 16: Toolchain Utilities (EBCDIC converter, COMP-3 converter)

## Deliverables

- `18-data-migration/data-extraction-plan.md` — Batch load, CDC, and replication strategy
- `18-data-migration/etl-pipeline-design.md` — ETL pipeline architecture with tooling selection
- `18-data-migration/data-validation-rules.md` — Row counts, checksums, and sampling rules
- `18-data-migration/rollback-strategy.md` — Rollback SOP and gating criteria
- `18-data-migration/dual-write-reconciliation.md` — Dual-write reconciliation process
- `18-data-migration/cutover-criteria.md` — Cutover decision criteria
- `18-data-migration/flyway-validation-queries.sql` — Validation SQL for each migrated table

## Data Extraction Strategies

### Strategy Selection Matrix

| Strategy | Best For | Downtime Required | Complexity | Data Freshness |
|----------|----------|-------------------|------------|---------------|
| **Batch Load (Full Extract)** | ≤100GB total data, weekend cutover window | Yes (4-12h) | Low | Snapshot at extraction time |
| **Batch Load (Incremental)** | >100GB, phased migration by functional area | Yes per phase (1-2h each) | Medium | Snapshot + delta |
| **CDC (Change Data Capture)** | Zero-downtime requirement, continuous sync | No | High | Near real-time |
| **Log-based Replication** | DB2→PostgreSQL direct replication | No | High | Near real-time |

### Batch Load Strategy (Recommended Default)

```
Mainframe (VSAM/DB2)
    │
    ├── Step 1: UNLOAD/reorg data → flat files (EBCDIC)
    │     Tools: IBM DFSORT, IDCAMS REPRO, DB2 UNLOAD
    │     Output: .DAT files per VSAM file / DB2 table
    │
    ├── Step 2: FTP/SFTP files → staging server
    │     Protocol: SFTP with checksum verification
    │     Target: /data/staging/YEAR-MON-DAY/
    │
    ├── Step 3: Convert EBCDIC → UTF-8 (Phase 16 utility)
    │     Tool: EbcdicToUtf8Converter.java
    │     Output: .utf8 files
    │
    ├── Step 4: Validate flat file integrity
    │     Checks: row count = VSAM LISTCAT count
    │     Checks: file size within expected range
    │     Checks: no truncation (last record complete)
    │
    ├── Step 5: Load into PostgreSQL staging tables
    │     Tool: PostgreSQL COPY command
    │     Method: TRUNCATE staging → COPY FROM → ANALYZE
    │
    └── Step 6: Transform and merge → production tables
          Apply: COMP-3 → BigDecimal conversion
          Apply: date format conversion (YYMMDD → ISO8601)
          Apply: foreign key resolution
```

### CDC Strategy (Zero-Downtime)

```
Mainframe CICS/DB2
    │
    ├── IBM InfoSphere CDC / Oracle GoldenGate
    │   or
    │   Debezium with DB2 connector (if DB2 LUW)
    │
    ├── Capture INSERT/UPDATE/DELETE from DB2 transaction log
    │
    ├── Publish to Kafka topic
    │     Topic: cdc.{schema}.{table}
    │     Format: Debezium JSON with before/after images
    │
    ├── Kafka Connect JDBC Sink → PostgreSQL
    │     Apply transformations: EBCDIC→UTF-8, COMP-3→BigDecimal
    │     Conflict resolution: last-write-wins with timestamps
    │
    └── Monitoring: Lag dashboard in Grafana
```

## ETL Pipeline Design

### Tooling Stack

| Stage | Tool | Purpose |
|-------|------|---------|
| Extract | IBM DFSORT / IDCAMS / DB2 UNLOAD | Mainframe data extraction |
| Transfer | SFTP + `sha256sum` | Secure file transfer with integrity check |
| Convert | Phase 16 `EbcdicToUtf8Converter` | EBCDIC→UTF-8 encoding |
| Transform | Python + Pandas or Apache Spark | Field-level transformations |
| Load | PostgreSQL `COPY` command | High-performance bulk load |
| Orchestrate | Apache Airflow or Spring Batch | Job scheduling, retry, alerting |

### Airflow DAG Template

```python
# etl_dag.py — Airflow DAG for data migration pipeline
from airflow import DAG
from airflow.operators.bash import BashOperator
from airflow.operators.python import PythonOperator
from datetime import datetime, timedelta

default_args = {
    'owner': 'data-migration',
    'depends_on_past': False,
    'retries': 3,
    'retry_delay': timedelta(minutes=5),
    'email_on_failure': True
}

dag = DAG(
    'vsam_to_postgresql_migration',
    default_args=default_args,
    start_date=datetime(2026, 1, 1),
    schedule_interval=None,
    catchup=False
)

def validate_file_integrity(**context):
    table = context['params']['table']
    expected_rows = context['params']['expected_rows']
    file_path = f"/data/staging/{table}.utf8"
    actual_rows = sum(1 for _ in open(file_path))
    if actual_rows != expected_rows:
        raise ValueError(f"Row count mismatch: {actual_rows} vs {expected_rows}")

extract = BashOperator(task_id='extract_mainframe', dag=dag,
    bash_command='ssh mainframe "//EXTRACT.JCL"')
transfer = BashOperator(task_id='transfer_files', dag=dag,
    bash_command='sftp -b transfer.batch batch@staging-server')
convert = BashOperator(task_id='convert_ebcdic', dag=dag,
    bash_command='java EbcdicToUtf8Converter /data/staging/ /data/converted/')
validate = PythonOperator(task_id='validate_integrity', dag=dag,
    python_callable=validate_file_integrity,
    params={'table': 'CARDS', 'expected_rows': 150000})
transform = BashOperator(task_id='transform_compute', dag=dag,
    bash_command='python transform_field_types.py /data/converted/ /data/transformed/')
load = BashOperator(task_id='load_postgresql', dag=dag,
    bash_command='psql -f load_staging.sql')

extract >> transfer >> convert >> validate >> transform >> load
```

## Data Validation Rules

### Validation Framework

All validation rules fall into three tiers:

**Tier 1 — Structural (must pass before any data load):**
- Row counts match VSAM `LISTCAT` totals (±0)
- File sizes match expected range (original_iobytes × 0.9 to 1.1)
- No truncated records (last record completes at RECLN boundary)
- All primary key values present and non-null

**Tier 2 — Semantic (must pass before production sign-off):**
- All foreign keys resolve to existing records (RI check)
- Date fields are valid dates (not 00/00/00 unless COBOL allows)
- Amount fields are valid decimals (no hex garbage in COMP-3 fields)
- Status fields contain only valid enum codes from Phase 4

**Tier 3 — Business Logic (must pass during UAT):**
- Account balances reconcile (SUM(debits) + SUM(credits) = 0)
- Control totals match (batch header totals = SUM(detail records))
- No negative inventory / balance anomalies from boundary conditions

### Flyway Migration Validation Queries

```sql
-- flyway-validation-queries.sql
-- Run AFTER each Flyway migration to validate data integrity
-- Place in: src/test/resources/db/validation/

-- Validation 1: Row count parity with VSAM source
DO $$
DECLARE
    expected_count BIGINT;
    actual_count   BIGINT;
    table_name     TEXT;
BEGIN
    FOR table_name IN
        SELECT UNNEST(ARRAY['cards', 'accounts', 'transactions', 'users'])
    LOOP
        EXECUTE format('SELECT COUNT(*) FROM %I', table_name) INTO actual_count;
        expected_count := (SELECT record_count FROM migration_tracking WHERE source_name = table_name);

        IF actual_count != expected_count THEN
            RAISE EXCEPTION 'Row count mismatch for %: expected=%, actual=%',
                table_name, expected_count, actual_count;
        END IF;

        RAISE NOTICE 'Table % validated: % rows', table_name, actual_count;
    END LOOP;
END $$;

-- Validation 2: Primary key uniqueness
SELECT 'cards' AS table_name, COUNT(*) - COUNT(DISTINCT card_number) AS duplicate_keys
FROM cards HAVING COUNT(*) != COUNT(DISTINCT card_number)
UNION ALL
SELECT 'accounts', COUNT(*) - COUNT(DISTINCT account_id)
FROM accounts HAVING COUNT(*) != COUNT(DISTINCT account_id);

-- Validation 3: Foreign key referential integrity
SELECT 'cards.account_id' AS fk_name, COUNT(*) AS orphan_count
FROM cards c LEFT JOIN accounts a ON c.account_id = a.account_id
WHERE a.account_id IS NULL AND c.account_id IS NOT NULL
HAVING COUNT(*) > 0;

-- Validation 4: Checksum verification (MD5 of concatenated row values)
SELECT 'cards' AS table_name, MD5(STRING_AGG(
    COALESCE(card_number, '') || '|' ||
    COALESCE(account_id, '') || '|' ||
    COALESCE(balance::TEXT, '') || '|' ||
    COALESCE(status, ''),
    '' ORDER BY card_number
)) AS computed_checksum
FROM cards;

-- Validation 5: COMP-3 → BigDecimal correctness (spot-check 1%)
SELECT card_number, balance
FROM cards
WHERE balance != ROUND(balance, 2)  -- Detect precision errors
LIMIT 10;

-- Validation 6: Amount sign correctness
SELECT 'cards.balance_negative' AS check_name, COUNT(*) AS violation_count
FROM cards WHERE balance < 0 AND status = 'ACTIVE'
HAVING COUNT(*) > 0;

-- Validation 7: Date validity
SELECT 'cards.expiry_date_future' AS check_name, COUNT(*) AS violation_count
FROM cards WHERE expiry_date < CURRENT_DATE AND status = 'ACTIVE'
HAVING COUNT(*) > 0;

-- Validation 8: Enum code validity
SELECT DISTINCT status FROM cards
WHERE status NOT IN ('A', 'I', 'B', 'C')
UNION ALL
SELECT DISTINCT account_type FROM accounts
WHERE account_type NOT IN ('CHK', 'SAV', 'CRD');
```

### Automated Validation Script (Python)

```python
#!/usr/bin/env python3
# validate_migration.py — Runs all validation queries and generates report

import psycopg2
import sys

VALIDATION_QUERIES = {
    'row_count_parity': 'SELECT ... FROM validation_1',
    'pk_uniqueness': 'SELECT ... FROM validation_2',
    'fk_integrity': 'SELECT ... FROM validation_3',
    'checksum_verification': 'SELECT ... FROM validation_4',
}

def run_validation(conn, report_file):
    passed = 0
    failed = 0

    with open(report_file, 'w') as report:
        for name, query in VALIDATION_QUERIES.items():
            try:
                cur = conn.cursor()
                cur.execute(query)
                result = cur.fetchone()
                if result and result[0] > 0:
                    report.write(f"[FAIL] {name}: {result}\n")
                    failed += 1
                else:
                    report.write(f"[PASS] {name}\n")
                    passed += 1
            except Exception as e:
                report.write(f"[ERROR] {name}: {str(e)}\n")
                failed += 1

        report.write(f"\nSUMMARY: {passed} passed, {failed} failed\n")

    return failed == 0

if __name__ == '__main__':
    conn = psycopg2.connect("postgresql://user:pass@localhost/cobol_migration")
    success = run_validation(conn, 'validation-report.txt')
    conn.close()
    sys.exit(0 if success else 1)
```

## Rollback Strategy

### Rollback Standard Operating Procedure (SOP)

```
ROLLBACK TRIGGER GATES (any one triggers rollback):
├── G1: Row count mismatch >0.01% on any critical table
├── G2: Validation Tier 2 fails (FK integrity, date validity, enum codes)
├── G3: Application smoke tests fail on migrated database
├── G4: Performance regression >20% on top-10 queries
└── G5: Cutover window exceeded by >50%

ROLLBACK PROCEDURE (estimated time: 30min):
├── Step 1: Halt application traffic
│     kubectl scale deployment app-deployment --replicas=0
│
├── Step 2: Switch DNS/LB back to mainframe CICS
│     Route 53 weighted record: mainframe=100, cloud=0
│
├── Step 3: Re-enable VSAM/DB2 write access on mainframe
│     Resume CICS transactions, unquiesce DB2 tables
│
├── Step 4: Replay any transactions that were dual-written
│     during cutover window from Kafka replay topic
│
└── Step 5: Verify mainframe system health
      Run smoke test batch against CICS programs
      Verify VSAM record counts unchanged
```

### Rollback Decision Matrix

| Condition | Action | Owner | Time Limit |
|-----------|--------|-------|-----------|
| Row count mismatch >0.01% on ≤2 non-critical tables | Pause, investigate, retry after fix | DBA Lead | 2h |
| Row count mismatch on ≥3 tables or any critical table | Full rollback | Migration Lead | 30min |
| FK integrity violation found | Full rollback | Migration Lead | 30min |
| App smoke test passes, minor UI issue | Proceed with known issues documented | Tech Lead | Immediate |
| App smoke test fails | Full rollback | Migration Lead | 30min |
| Performance regression ≤20% | Proceed, tune post-migration | Performance Lead | Immediate |
| Performance regression >20% | Full rollback | Migration Lead | 30min |
| Cutover window exceeded | Full rollback | Program Manager | Immediate |

## Dual-Write Reconciliation Process

### Architecture

```
                ┌──────────────┐
                │  Application │
                │  (Java/Spring)│
                └──────┬───────┘
                       │
              ┌────────┴────────┐
              ▼                 ▼
        ┌──────────┐     ┌──────────┐
        │PostgreSQL│     │  Kafka   │
        │ (Primary)│     │ (Mirror) │
        └──────────┘     └────┬─────┘
                              │
                    ┌─────────▼─────────┐
                    │ Mainframe Adapter │
                    │ (writes to VSAM)  │
                    └───────────────────┘
```

### Reconciliation Query

```sql
-- dual-write-reconciliation.sql
-- Compares PostgreSQL records with mainframe VSAM for discrepancies

WITH pg_data AS (
    SELECT card_number, account_id, balance, status, updated_at
    FROM cards
    WHERE updated_at >= NOW() - INTERVAL '1 hour'
),
vsam_data AS (
    SELECT card_number, account_id, balance, status, updated_at
    FROM cards_vsam_mirror  -- Mirror table loaded from mainframe extract
    WHERE updated_at >= NOW() - INTERVAL '1 hour'
)
SELECT 'MISSING_IN_PG' AS discrepancy_type, v.*
FROM vsam_data v LEFT JOIN pg_data p ON v.card_number = p.card_number
WHERE p.card_number IS NULL
UNION ALL
SELECT 'MISSING_IN_VSAM' AS discrepancy_type, p.*
FROM pg_data p LEFT JOIN vsam_data v ON p.card_number = v.card_number
WHERE v.card_number IS NULL
UNION ALL
SELECT 'BALANCE_MISMATCH' AS discrepancy_type, p.*
FROM pg_data p JOIN vsam_data v ON p.card_number = v.card_number
WHERE p.balance != v.balance
UNION ALL
SELECT 'STATUS_MISMATCH' AS discrepancy_type, p.*
FROM pg_data p JOIN vsam_data v ON p.card_number = v.card_number
WHERE p.status != v.status;
```

### Auto-Reconciliation Job

```java
// DualWriteReconciliationJob.java
// Runs every 5 minutes during dual-write phase, auto-resolves conflicts
@Component
@Slf4j
public class DualWriteReconciliationJob {

    private final JdbcTemplate jdbc;
    private final KafkaTemplate<String, ResolutionEvent> kafka;

    @Scheduled(fixedDelay = 300_000)
    public void reconcile() {
        List<Discrepancy> discrepancies = jdbc.query(
            RECONCILIATION_SQL, new DiscrepancyRowMapper());

        for (Discrepancy d : discrepancies) {
            switch (d.type()) {
                case MISSING_IN_PG:
                    replayToPostgres(d.vsamRecord());
                    break;
                case MISSING_IN_VSAM:
                    replayToMainframe(d.pgRecord());
                    break;
                case BALANCE_MISMATCH, STATUS_MISMATCH:
                    resolveByTimestamp(d);  // Last-write-wins
                    break;
            }
        }

        log.info("Reconciliation complete: {} discrepancies resolved",
            discrepancies.size());
    }
}
```

## Cutover Criteria

### Go/No-Go Checklist

```
CUTOVER DECISION CHECKLIST
=========================

Pre-Cutover (T-7 days):
[ ] All ETL pipelines tested end-to-end (3 successful dry runs)
[ ] Flyway validation queries all pass on staging database
[ ] Performance benchmarks met (Phase 20 — all SLAs within 20%)
[ ] Rollback SOP rehearsed and timed (<30 minutes)
[ ] Battle rhythm established (war room schedule, escalation contacts)

Cutover Window (T-0):
[ ] Mainframe database quiesced (no active writers)
[ ] Final data extraction complete with valid checksum
[ ] All Tier 1 validations pass (row counts, PK uniqueness)
[ ] All Tier 2 validations pass (FK integrity, dates, enums)
[ ] Sample Tier 3 validations pass (balance reconciliation, control totals)
[ ] Application deployed to production K8s cluster
[ ] Smoke tests pass (10 critical business flows)
[ ] Monitoring dashboards green (no alerts on latency/error rate)

Post-Cutover (T+1h):
[ ] User acceptance tests in progress
[ ] Mainframe kept warm as rollback target for 72h
[ ] Dual-write active (if incremental cutover)

BEFORE SIGNING "GO":
[ ] Migration Lead: ___________________ Date: ___________
[ ] DBA Lead: _________________________ Date: ___________
[ ] QA Lead: __________________________ Date: ___________
[ ] Business Sponsor: __________________ Date: ___________
```

## Execution Steps

### Step 1: Profile Data Volumes

For each VSAM file from Phase 2, catalog:
- Total record count (from `LISTCAT`)
- Total data size in bytes
- Average/median/max record length
- Primary key cardinality and distribution
- Identified encoding (EBCDIC code page)

### Step 2: Select Extraction Strategy

Based on data volume and downtime tolerance, choose from the strategy matrix. Default: Batch Load with incremental phases for very large datasets (>1M records per table).

### Step 3: Build ETL Pipeline

Implement the chosen ETL pipeline using the tooling stack. Containerize all ETL jobs for repeatable execution.

### Step 4: Implement Validation Rules

Write all Tier 1-3 validation queries. Run them automatically after each ETL job. Fail the pipeline if any Tier 1 or Tier 2 validation fails.

### Step 5: Document Rollback SOP

Produce `rollback-strategy.md` with the exact rollback procedure, timing estimates, and decision matrix.

### Step 6: Set Up Dual-Write (if applicable)

If using incremental cutover, configure the dual-write pipeline and reconciliation job.

### Step 7: Run Dry Runs

Execute the full migration pipeline 3 times against staging environment:
- Dry run 1: Verify pipeline completes without errors
- Dry run 2: Verify validation pass rates ≥ 99.9%
- Dry run 3: Verify performance meets Phase 20 SLAs

### Step 8: Execute Production Cutover

Follow the cutover checklist. Staff the war room with all required roles.

## Quality Gate

- [ ] ETL pipeline completes end-to-end in staging (3 consecutive successful runs)
- [ ] All Tier 1 validations pass (row count = source, PK unique, file complete)
- [ ] All Tier 2 validations pass (FK integrity, date validity, enum codes)
- [ ] Flyway validation queries integrated into CI/CD pipeline
- [ ] Rollback SOP documented and rehearsed (total rollback time <30 min)
- [ ] Dual-write reconciliation running with <0.01% discrepancy rate (if applicable)
- [ ] Cutover criteria checklist signed by all stakeholders
- [ ] Mainframe kept warm as rollback target for minimum 72 hours post-cutover
- [ ] Validation report generated and archived with migration runbook
- [ ] `_state-snapshot.json` updated to `{'phase':18,'status':'complete'}`
