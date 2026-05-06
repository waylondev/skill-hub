# Data Engineering — Architect-Level Reference

## Purpose

This reference encodes **production-grade data engineering patterns** used by architects to design pipelines, lakes, and streaming systems. It covers CDC, ETL/ELT, data quality, stream processing, observability, governance, and anti-patterns.

When you need to make a data-system decision — batch vs streaming, schema evolution, backfill strategy — consult this file.

---

## 1. CDC (Change Data Capture) with Debezium

**Use when**: You need to replicate database changes to downstream systems (data lake, search index, cache, event bus) with low latency and without polling.

### Architecture

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────────┐
│  PostgreSQL │────▶│  Debezium   │────▶│    Kafka    │────▶│  Consumer Apps  │
│  (source)   │ WAL │  Connector  │     │  (topics)   │     │ (lake, index)   │
└─────────────┘     └─────────────┘     └─────────────┘     └─────────────────┘
```

Debezium reads the database transaction log (WAL / binlog) — not the tables. This means:
- **No query load** on the source database (unlike timestamp polling)
- **Captures DELETEs** (polling cannot)
- **Ordered, exactly-once** per partition when paired with Kafka transactions

### Connector Configuration (PostgreSQL)

```json
{
  "name": "inventory-connector",
  "config": {
    "connector.class": "io.debezium.connector.postgresql.PostgresConnector",
    "database.hostname": "postgres.internal",
    "database.port": "5432",
    "database.user": "debezium",
    "database.password": "${secrets:debezium-pass}",
    "database.dbname": "inventory",
    "database.server.name": "dbserver1",
    "table.include.list": "public.orders,public.order_items",
    "plugin.name": "pgoutput",
    "slot.name": "debezium_slot",
    "publication.name": "dbz_publication",
    "snapshot.mode": "initial",
    "tombstones.on.delete": true,
    "decimal.handling.mode": "string",
    "time.precision.mode": "connect",
    "heartbeat.interval.ms": 10000,
    "heartbeat.action.query": "INSERT INTO debezium_heartbeat (id, ts) VALUES (1, NOW()) ON CONFLICT (id) DO UPDATE SET ts = NOW();"
  }
}
```

**Critical settings**:
- `slot.name`: Logical replication slot. If the connector restarts, it resumes from this LSN. **Never delete the slot** unless you intend full re-snapshot.
- `heartbeat.action.query`: For low-traffic tables, PostgreSQL may recycle WAL segments before Debezium reads them. A heartbeat table forces WAL rotation.
- `snapshot.mode`: `initial` = snapshot + streaming. `schema_only` = no data, just schema. `never` = streaming only (assumes snapshot already done).

### Debezium Event Format

```json
{
  "before": {
    "id": 1001,
    "status": "PENDING",
    "total": "199.99"
  },
  "after": {
    "id": 1001,
    "status": "PAID",
    "total": "199.99"
  },
  "source": {
    "version": "2.5.0.Final",
    "connector": "postgresql",
    "name": "dbserver1",
    "ts_ms": 1714992000123,
    "db": "inventory",
    "schema": "public",
    "table": "orders",
    "txId": 12345,
    "lsn": 123456789
  },
  "op": "u",
  "ts_ms": 1714992000156
}
```

| Field | Meaning |
|-------|---------|
| `op` | `c` = create, `u` = update, `d` = delete, `r` = read (snapshot) |
| `before` | Row state before change (null for `c`) |
| `after` | Row state after change (null for `d`) |
| `source.ts_ms` | Commit timestamp in source DB |
| `source.txId` | Transaction ID — use to group changes in the same TX |

### Consumer Idempotency Pattern

```java
@Component
public class OrderEventHandler {
    private final OrderSearchIndex index;
    private final ProcessedOffsetRepository offsetRepo;

    @KafkaListener(topics = "dbserver1.public.orders", groupId = "search-indexer")
    public void onEvent(ConsumerRecord<String, String> record) {
        var event = Json.parse(record.value(), DebeziumEvent.class);
        var offsetKey = record.topic() + ":" + record.partition() + ":" + record.offset();

        // Idempotency: skip if already processed
        if (offsetRepo.exists(offsetKey)) {
            return;
        }

        switch (event.op()) {
            case "c", "u", "r" -> index.upsert(parseOrder(event.after()));
            case "d" -> index.delete(event.before().id());
        }

        offsetRepo.save(offsetKey, Instant.now());
    }
}
```

**Rule**: Every CDC consumer must store its offset in the same transaction as the side effect, OR use Kafka consumer group commits with at-least-once + idempotent writes.

---

## 2. ETL/ELT Pipeline Design Principles

**Use when**: Moving data between systems. The E vs L vs T order is a strategic decision, not a default.

### ETL vs ELT Decision Matrix

| Factor | ETL | ELT |
|--------|-----|-----|
| **Transform complexity** | Heavy (joins, business rules) | Light (casting, filtering) |
| **Target compute** | Weak (old RDBMS, small warehouse) | Strong (Snowflake, BigQuery, Spark) |
| **Data volume** | Small-medium | Large |
| **Schema stability** | Stable | Evolving |
| **Regulatory** | PII must be masked before landing | PII masked in target via policies |
| **Example** | Salesforce → PostgreSQL with enrichment | Raw JSON logs → Snowflake → dbt models |

### Idempotency

Every pipeline stage must be safely re-runnable.

```sql
-- Idempotent load: MERGE (UPSERT) instead of INSERT
MERGE INTO dw.orders AS target
USING staging.orders AS source
ON target.order_id = source.order_id
WHEN MATCHED THEN UPDATE SET
    status = source.status,
    total = source.total,
    updated_at = source.updated_at
WHEN NOT MATCHED THEN INSERT (order_id, status, total, created_at, updated_at)
    VALUES (source.order_id, source.status, source.total, source.created_at, source.updated_at);
```

```python
# Idempotent Spark write with overwrite by partition
(df.write
   .mode("overwrite")
   .option("partitionOverwriteMode", "dynamic")  # only overwrite touched partitions
   .partitionBy("dt")
   .parquet("s3://datalake/orders/"))
```

### Backfill Strategies

| Strategy | When to Use | Risk |
|----------|-------------|------|
| **Full re-snapshot** | Small table (< 10M rows), schema changed | High load on source |
| **Partitioned backfill** | Large table, time-partitioned target | Must align partition keys |
| **CDC rewind** | Logical slot available, bounded time window | Slot may have been recycled |
| **Incremental watermark** | `updated_at` column exists | Misses hard deletes without CDC |

```sql
-- Incremental watermark backfill
INSERT INTO dw.orders
SELECT * FROM source.orders
WHERE updated_at > (SELECT MAX(updated_at) FROM dw.orders)
   OR updated_at IS NULL;

-- Store watermark for next run
UPDATE pipeline.watermarks SET last_value = (SELECT MAX(updated_at) FROM dw.orders)
WHERE table_name = 'orders';
```

**Golden rule**: Every pipeline must have a documented backfill procedure before it goes to production. "We can't backfill" is not acceptable.

---

## 3. Data Consistency Validation Patterns

**Use when**: You need to prove that data in system A matches system B, or detect silent corruption.

### Reconciliation Jobs

```python
from pyspark.sql import SparkSession, functions as F

spark = SparkSession.builder.appName("reconciliation").getOrCreate()

source = spark.read.jdbc(url=pg_url, table="orders")
target = spark.read.parquet("s3://datalake/orders/dt=2024-05-01")

# Row-level reconciliation
comparison = source.alias("s").join(
    target.alias("t"),
    F.col("s.order_id") == F.col("t.order_id"),
    "full_outer"
).select(
    F.coalesce("s.order_id", "t.order_id").alias("order_id"),
    (F.col("s.status") == F.col("t.status")).alias("status_match"),
    (F.col("s.total") == F.col("t.total")).alias("total_match"),
    F.when(F.col("s.order_id").isNull(), "MISSING_IN_SOURCE")
     .when(F.col("t.order_id").isNull(), "MISSING_IN_TARGET")
     .otherwise("MATCH").alias("recon_status")
)

mismatches = comparison.filter(F.col("recon_status") != "MATCH")
mismatches.write.parquet("s3://datalake/recon/mismatches/dt=2024-05-01")
```

### Checksum Validation

```java
// Per-batch checksum for file-based pipelines
public String computeChecksum(Path file) throws IOException {
    var digest = MessageDigest.getInstance("SHA-256");
    try (var is = Files.newInputStream(file)) {
        byte[] buffer = new byte[8192];
        int read;
        while ((read = is.read(buffer)) != -1) {
            digest.update(buffer, 0, read);
        }
    }
    return Base64.getEncoder().encodeToString(digest.digest());
}

// Store checksum in pipeline metadata table
// On read, recompute and compare. Mismatch = corruption or tampering.
```

### Anomaly Detection (Statistical)

```sql
-- Z-score based anomaly detection on daily order volume
WITH daily_stats AS (
    SELECT
        dt,
        COUNT(*) AS order_count,
        AVG(COUNT(*)) OVER (ORDER BY dt ROWS BETWEEN 29 PRECEDING AND CURRENT ROW) AS avg_30d,
        STDDEV(COUNT(*)) OVER (ORDER BY dt ROWS BETWEEN 29 PRECEDING AND CURRENT ROW) AS stddev_30d
    FROM dw.orders
    GROUP BY dt
)
SELECT dt, order_count,
       (order_count - avg_30d) / NULLIF(stddev_30d, 0) AS z_score
FROM daily_stats
WHERE ABS((order_count - avg_30d) / NULLIF(stddev_30d, 0)) > 3;
```

---

## 4. Data Versioning and Schema Evolution

**Use when**: You need time-travel queries, safe schema changes, or concurrent read/write on the same dataset.

### Delta Lake

```python
from delta import DeltaTable

# Time travel
spark.read.format("delta").option("versionAsOf", 5234).load("/delta/orders")
spark.read.format("delta").option("timestampAsOf", "2024-05-01T00:00:00Z").load("/delta/orders")

# Schema enforcement + evolution
(df.write
   .format("delta")
   .mode("append")
   .option("mergeSchema", "true")   # allow safe schema evolution
   .save("/delta/orders"))

# VACUUM old versions (retention policy)
delta_table = DeltaTable.forPath(spark, "/delta/orders")
delta_table.vacuum(168)  # retain 7 days (168 hours)
```

**Delta Lake guarantees**: ACID transactions, scalable metadata, time travel, unified batch/streaming.

### Apache Iceberg

```java
// Java API — Iceberg table operations
Table table = catalog.loadTable(TableIdentifier.of("warehouse", "orders"));

// Append with snapshot isolation
Transaction txn = table.newTransaction();
txn.newAppend().appendFile(dataFile).commit();
txn.commitTransaction();

// Time travel
Table snapshotTable = table.snapshotAsOfTime(Instant.parse("2024-05-01T00:00:00Z"));
```

**Iceberg vs Delta**: Iceberg has better engine-agnosticism (Trino, Flink, Spark, Hive all read the same table). Delta is simpler to operate in pure-Spark environments.

### Schema Evolution Rules

| Change | Safe? | Notes |
|--------|-------|-------|
| Add optional column | Yes | Default null |
| Add required column | No | Breaks old readers/writers |
| Widen type (INT → BIGINT) | Usually | Check engine support |
| Narrow type (BIGINT → INT) | No | Data loss risk |
| Rename column | No | Use add + drop + backfill if needed |
| Drop column | Careful | Old snapshots still have it |

**Rule**: Schema changes go through a pipeline, not ad-hoc. Use a schema registry (Confluent Schema Registry for Avro/Protobuf/JSON Schema) to enforce compatibility modes:
- `BACKWARD`: New readers read old data
- `FORWARD`: Old readers read new data
- `FULL`: Both (safest, most restrictive)

---

## 5. Data Quality Frameworks

**Use when**: You need automated, continuous validation that data meets business expectations.

### Great Expectations (Python)

```python
import great_expectations as gx

context = gx.get_context()
datasource = context.sources.add_pandas("orders")
data_asset = datasource.add_dataframe_asset(name="orders_df")

batch_request = data_asset.build_batch_request(dataframe=df)

validator = context.get_validator(
    batch_request=batch_request,
    expectation_suite_name="orders_suite"
)

validator.expect_column_values_to_not_null("order_id")
validator.expect_column_values_to_be_unique("order_id")
validator.expect_column_values_to_be_between("total", min_value=0)
validator.expect_column_values_to_be_in_set("status", ["PENDING", "PAID", "SHIPPED", "CANCELLED"])
validator.expect_table_row_count_to_be_between(min_value=1000, max_value=10000000)

validator.save_expectation_suite(discard_failed_expectations=False)
checkpoint = context.add_or_update_checkpoint(
    name="orders_checkpoint",
    validator=validator,
)
checkpoint_result = checkpoint.run()
```

### dbt Tests

```yaml
# models/schema.yml
version: 2

models:
  - name: stg_orders
    columns:
      - name: order_id
        tests:
          - unique
          - not_null
      - name: status
        tests:
          - accepted_values:
              values: ['PENDING', 'PAID', 'SHIPPED', 'CANCELLED']
      - name: total
        tests:
          - dbt_utils.expression_is_true:
              expression: ">= 0"

  - name: fct_orders
    tests:
      - dbt_utils.equal_rowcount:
          compare_model: ref('stg_orders')
```

### Data Contracts

A data contract is an explicit agreement between producer and consumer, enforced at build time or runtime.

```yaml
# contracts/orders.v1.yaml
apiVersion: "datacontract.com/v1"
id: orders
owner: data-platform-team
schema:
  type: object
  required: [order_id, status, total, created_at]
  properties:
    order_id:
      type: string
      format: uuid
    status:
      type: string
      enum: [PENDING, PAID, SHIPPED, CANCELLED]
    total:
      type: number
      minimum: 0
    created_at:
      type: string
      format: date-time
quality:
  freshness:
    maximum_delay: 1h
  completeness:
    required_fields: [order_id, status, total]
sla:
  availability: 99.9%
  p99_latency: 200ms
```

---

## 6. Stream Processing Patterns

**Use when**: You need sub-second latency, continuous computation, or event-driven reactions.

### Kafka Streams

```java
StreamsBuilder builder = new StreamsBuilder();
KStream<String, OrderEvent> orders = builder.stream("orders",
    Consumed.with(Serdes.String(), orderEventSerde));

// Stateful aggregation: revenue per category per hour
orders
    .selectKey((k, v) -> v.category())
    .groupByKey()
    .windowedBy(TimeWindows.ofSizeWithNoGrace(Duration.ofHours(1)))
    .aggregate(
        () -> new RevenueAggregate(),
        (key, event, agg) -> agg.add(event.amount()),
        Materialized.with(Serdes.String(), revenueSerde)
    )
    .toStream()
    .to("hourly-revenue", Produced.with(windowedSerde, revenueSerde));

// Exactly-once processing
Properties props = new Properties();
props.put(StreamsConfig.PROCESSING_GUARANTEE_CONFIG, StreamsConfig.EXACTLY_ONCE_V2);
props.put(StreamsConfig.NUM_STREAM_THREADS_CONFIG, 4);
```

### Apache Flink

```java
StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();
env.enableCheckpointing(60000, CheckpointingMode.EXACTLY_ONCE);
env.getCheckpointConfig().setCheckpointStorage("s3://datalake/checkpoints/orders");

DataStream<OrderEvent> orders = env
    .fromSource(kafkaSource, WatermarkStrategy
        .<OrderEvent>forBoundedOutOfOrderness(Duration.ofMinutes(5))
        .withTimestampAssigner((event, ts) -> event.eventTime()), "Kafka Orders");

// Windowed aggregation with late data handling
orders
    .keyBy(OrderEvent::category)
    .window(TumblingEventTimeWindows.of(Time.hours(1)))
    .allowedLateness(Time.minutes(10))
    .sideOutputLateData(lateDataTag)
    .aggregate(new RevenueAggregateFunction())
    .addSink(new FlinkKafkaProducer<>("hourly-revenue", revenueSerializer, kafkaProps));

env.execute("Hourly Revenue Aggregation");
```

### Exactly-Once Semantics

| Layer | Mechanism |
|-------|-----------|
| **Kafka Producer** | Idempotent producer (`enable.idempotence=true`) + transactions |
| **Kafka Consumer** | Store offsets in external system with consumer-side transaction |
| **Flink** | Checkpoint barriers + async snapshots to durable storage |
| **Kafka Streams** | EOS v2: transactional producer + consumer offset commits |

**Trade-off**: Exactly-once adds 10-30% latency overhead. Use at-least-once + idempotent consumers for latency-sensitive, idempotent operations.

---

## 7. Data Pipeline Observability

**Use when**: You need to know if your data is fresh, correct, and traceable.

### Lineage Tracking

```python
# OpenLineage integration (Spark)
from pyspark.sql import SparkSession

spark = (SparkSession.builder
    .config("spark.extraListeners", "io.openlineage.spark.agent.OpenLineageSparkListener")
    .config("spark.openlineage.transport.type", "http")
    .config("spark.openlineage.transport.url", "http://marquez:5000")
    .getOrCreate())

# Every read/write is automatically emitted as lineage metadata
```

### SLA Monitoring

```yaml
# monitoring/sla_rules.yaml
rules:
  - name: orders_freshness
    table: dw.fct_orders
    metric: freshness
    threshold: "1 hour"
    alert_channel: pagerduty

  - name: orders_completeness
    table: dw.fct_orders
    metric: null_ratio
    column: order_id
    threshold: "0%"
    alert_channel: slack-data-quality

  - name: daily_volume_anomaly
    table: dw.fct_orders
    metric: row_count_vs_7d_avg
    threshold: "±30%"
    alert_channel: slack-data-platform
```

### Data Freshness Alerts

```sql
-- freshness check query (run by monitoring agent every 5 min)
SELECT
    table_name,
    MAX(event_time) AS last_event_time,
    EXTRACT(EPOCH FROM (NOW() - MAX(event_time))) / 60 AS lag_minutes
FROM dw.fct_orders
GROUP BY table_name
HAVING MAX(event_time) < NOW() - INTERVAL '1 hour';
```

---

## 8. Batch vs Streaming Decision Tree

```
Is latency requirement < 5 minutes?
├── YES → Streaming
│   ├── Is the computation stateful (joins, windows, aggregations)?
│   │   ├── YES → Flink or Kafka Streams with checkpointing
│   │   └── NO  → Kafka Consumer + simple transform
│   ├── Is exactly-once required?
│   │   ├── YES → Flink checkpointing or Kafka Streams EOS
│   │   └── NO  → At-least-once + idempotent sinks
│   └── Is the source a database?
│       ├── YES → Debezium CDC
│       └── NO  → Kafka / Kinesis / Pulsar directly
└── NO → Batch
    ├── Is data volume > 1TB per run?
    │   ├── YES → Spark / Trino on object storage
    │   └── NO  → dbt on warehouse (Snowflake/BigQuery)
    ├── Is schema evolving frequently?
    │   ├── YES → Delta Lake or Iceberg
    │   └── NO  → Plain Parquet / ORC
    └── Is there a dependency on streaming data?
        ├── YES → Lambda architecture (batch + streaming) or Kappa (streaming only)
        └── NO  → Pure batch pipeline
```

**Modern default**: Start with batch. Move to streaming only when business requirements force sub-minute latency. Streaming is 3-5x more expensive to operate.

---

## 9. Data Governance

**Use when**: You handle regulated data (PII, PHI, financial) or need access control at column/row level.

### PII Detection

```python
import presidio_analyzer as pa
from presidio_analyzer import AnalyzerEngine

analyzer = AnalyzerEngine()

def scan_for_pii(text: str) -> list[dict]:
    results = analyzer.analyze(text=text, language="en")
    return [
        {"type": r.entity_type, "start": r.start, "end": r.end, "score": r.score}
        for r in results if r.score > 0.8
    ]

# Scan column samples during ingestion
sample = df.select("customer_notes").limit(1000).collect()
for row in sample:
    pii = scan_for_pii(row.customer_notes)
    if pii:
        raise PiiDetectedException(f"PII detected in customer_notes: {pii}")
```

### Data Classification

```sql
-- Tag columns with classification metadata
CREATE TABLE data_catalog.column_tags (
    table_schema VARCHAR,
    table_name VARCHAR,
    column_name VARCHAR,
    classification VARCHAR,  -- 'PII', 'PCI', 'PUBLIC', 'INTERNAL'
    masking_policy VARCHAR,
    updated_at TIMESTAMP
);

-- Apply row-level security based on classification
CREATE POLICY mask_pii ON dw.customers
    FOR SELECT
    USING (current_user_role() IN ('ANALYST_PRIVILEGED', 'ADMIN'));

ALTER TABLE dw.customers
    ALTER COLUMN email SET MASKING POLICY partial_mask;
```

### Access Control Patterns

| Pattern | Granularity | When to Use |
|---------|-------------|-------------|
| **RBAC** | Role-based | Standard analytics teams |
| **ABAC** | Attribute-based | Dynamic environments (tenant isolation) |
| **PBAC** | Policy-based | Regulatory compliance (GDPR, HIPAA) |
| **RLS** | Row-level | Multi-tenant warehouses |
| **CLS** | Column-level | PII masking for general analysts |

```python
# ABAC example: row-level filtering in Spark
from pyspark.sql import functions as F

def apply_abac(df, user: UserContext):
    if user.role == "ADMIN":
        return df
    if user.role == "REGIONAL_MANAGER":
        return df.filter(F.col("region") == user.region)
    if user.role == "ANALYST":
        return df.filter(F.col("status") == "PUBLIC")
    raise AccessDeniedException()
```

---

## 10. Common Data Engineering Anti-Patterns

### DE-AP-1: Hardcoded Schemas

**Symptom**: Schema embedded in code, not in a registry or config.

```python
# WRONG
schema = StructType([
    StructField("order_id", StringType(), False),
    StructField("status", StringType(), True),
    StructField("total", DoubleType(), True),
])
# Schema change requires code deployment + PR + review + deploy cycle
```

**Fix**: Externalize schema in a registry or config file. Validate at runtime.

```python
# RIGHT
schema = load_schema_from_registry("orders", version="latest")
validate(df, schema, mode="STRICT")
```

---

### DE-AP-2: Missing Backfill Procedure

**Symptom**: Pipeline runs fine day-to-day. When data corruption is discovered, there is no way to reprocess historical data.

**Fix**: Design backfill on day one.
- Store raw data immutably (bronze layer)
- Make transforms deterministic and idempotent
- Document the backfill command and test it quarterly

```bash
# Documented backfill procedure
spark-submit \
  --class com.example.BackfillOrders \
  --conf spark.backfill.start_date=2024-01-01 \
  --conf spark.backfill.end_date=2024-03-31 \
  backfill.jar
```

---

### DE-AP-3: No Data Quality Checks

**Symptom**: Bad data propagates from source to dashboard. Discovered by a business user, not the pipeline.

**Fix**: Gate every layer with quality checks.

```yaml
# dbt schema.yml — enforce at build time
models:
  - name: stg_orders
    tests:
      - unique: { column_name: order_id }
      - not_null: { column_name: total }
      - dbt_utils.expression_is_true:
          expression: "created_at <= CURRENT_TIMESTAMP"
```

---

### DE-AP-4: Streaming Without Watermarks

**Symptom**: Flink/Kafka Streams job accumulates state indefinitely, eventually OOMing.

**Fix**: Always define watermarks and allowed lateness.

```java
// WRONG: no watermark → infinite state
stream.keyBy(...).window(TumblingEventTimeWindows.of(Time.hours(1)));

// RIGHT: bounded lateness, state can be cleaned up
stream.assignTimestampsAndWatermarks(
    WatermarkStrategy.<Event>forBoundedOutOfOrderness(Duration.ofMinutes(10))
).keyBy(...).window(TumblingEventTimeWindows.of(Time.hours(1)))
 .allowedLateness(Time.minutes(5));
```

---

### DE-AP-5: Direct DB-to-DB Polling

**Symptom**: `SELECT * FROM orders WHERE updated_at > ?` running every minute, crushing source DB.

**Fix**: Use CDC (Debezium) for change propagation. Polling is acceptable only for systems without log access and < 1/min frequency.

---

### DE-AP-6: Mutable Data Lake Files

**Symptom**: Overwriting Parquet files in place, breaking concurrent readers and losing history.

**Fix**: Use Delta Lake or Iceberg. If plain Parquet is required, write to new paths and atomically swap.

```python
# WRONG: in-place overwrite
spark.write.mode("overwrite").parquet("s3://lake/orders/")

# RIGHT: Delta Lake with time travel
df.write.format("delta").mode("overwrite").save("/delta/orders/")
```

---

### DE-AP-7: Secrets in Pipeline Code

**Symptom**: Database passwords, API keys committed to Git in DAG files or notebooks.

**Fix**: Use a secrets manager (Vault, AWS Secrets Manager, Azure Key Vault) and inject at runtime.

```python
# WRONG
password = "SuperSecret123"

# RIGHT
import boto3
secret = boto3.client("secretsmanager").get_secret_value(SecretId="prod/postgres/orders")
password = json.loads(secret["SecretString"])["password"]
```

---

## Quick Checklist

Before deploying a data pipeline to production:

- [ ] CDC connector configured with heartbeat and logical replication slot?
- [ ] ETL/ELT order justified by target compute and transform complexity?
- [ ] Every stage is idempotent and safely re-runnable?
- [ ] Backfill procedure documented and tested?
- [ ] Reconciliation job compares source and target at least daily?
- [ ] Schema registry enforces BACKWARD/FULL compatibility?
- [ ] Data quality checks (Great Expectations / dbt tests) gate every layer?
- [ ] Stream processing uses watermarks and bounded state?
- [ ] Exactly-once vs at-least-once chosen deliberately with documented trade-off?
- [ ] Lineage metadata emitted for every read/write operation?
- [ ] SLA monitoring alerts on freshness, volume, and schema drift?
- [ ] PII detection runs on new columns and unstructured text fields?
- [ ] Access control (RBAC/ABAC/RLS/CLS) enforced at the warehouse layer?
- [ ] No secrets in code — all credentials injected from secrets manager?
- [ ] Delta Lake or Iceberg used for mutable datasets requiring time travel?
