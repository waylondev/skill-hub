# Phase 20: Performance Benchmarking

## Objective

Establish a repeatable performance benchmarking framework that measures the migrated Java application against defined SLAs and compares results with the original COBOL system. The benchmarks must cover common COBOL patterns (VSAM lookups, COMPUTE formulas, batch processing), define measurable performance SLAs, and provide methodology for apples-to-apples COBOL-vs-Java comparison.

## Input

- Phase 2: VSAM Analysis — I/O profiles, access frequencies, record volumes
- Phase 5: Logic Extraction — all computational patterns (COMPUTE, IF, SORT, MERGE)
- Phase 6: Architecture Blueprint — target concurrency and scaling model
- Phase 7: Testing Matrix — performance test scenarios
- Phase 13: Docker & Kubernetes — target infrastructure sizing

## Deliverables

- `20-performance-benchmarking/benchmark-templates/` — JMH benchmark templates
- `20-performance-benchmarking/performance-sla-definitions.md` — SLA matrix
- `20-performance-benchmarking/gatling-load-scripts/` — Gatling simulation scripts
- `20-performance-benchmarking/benchmark-comparison-methodology.md` — COBOL-vs-Java comparison
- `20-performance-benchmarking/benchmark-results/` — Results storage template

## JMH Benchmark Templates

### Benchmark 1: VSAM Key Lookup (Single Record)

```java
// VsAmKeyLookupBenchmark.java
// Benchmarks CICS READ (key-based lookup) → JPA findById()
// Source: COBOL EXEC CICS READ FILE('CARD') RIDFLD(cardNumber)

@BenchmarkMode(Mode.Throughput)
@OutputTimeUnit(TimeUnit.SECONDS)
@State(Scope.Benchmark)
@Warmup(iterations = 3, time = 1)
@Measurement(iterations = 5, time = 2)
public class VsAmKeyLookupBenchmark {

    private CardRepository repository;
    private List<String> cardNumbers;
    private int index;

    @Setup
    public void setup() {
        ApplicationContext context = SpringApplication.run(BenchmarkConfig.class);
        repository = context.getBean(CardRepository.class);
        cardNumbers = generateCardNumbers(10000);
    }

    @Benchmark
    public Optional<Card> keyLookup_IdMatch() {
        // Source: COBOL READ CARD-FILE with EXACT key match (RESP=0 expected)
        String cardNumber = cardNumbers.get(index++ % cardNumbers.size());
        return repository.findById(cardNumber);
    }

    @Benchmark
    public Optional<Card> keyLookup_NotFound() {
        // Source: COBOL READ with non-existent key (RESP=13 NOTFND)
        return repository.findById("9999999999999999");
    }

    @Benchmark
    @BenchmarkMode(Mode.AverageTime)
    @OutputTimeUnit(TimeUnit.MICROSECONDS)
    public Optional<Card> keyLookup_Latency() {
        String cardNumber = cardNumbers.get(index++ % cardNumbers.size());
        return repository.findById(cardNumber);
    }
}
```

### Benchmark 2: COMPUTE Financial Formula

```java
// CompuTeFinancialBenchmark.java
// Benchmarks COBOL COMPUTE → Java BigDecimal arithmetic
// Source: COBOL COMPUTE NEW-BALANCE = BALANCE + AMOUNT - FEE * INTEREST-RATE

@BenchmarkMode(Mode.Throughput)
@OutputTimeUnit(TimeUnit.SECONDS)
@State(Scope.Benchmark)
public class CompuTeFinancialBenchmark {

    private BigDecimal balance;
    private BigDecimal amount;
    private BigDecimal fee;
    private BigDecimal interestRate;

    @Setup
    public void setup() {
        balance = new BigDecimal("1500.00");
        amount = new BigDecimal("250.75");
        fee = new BigDecimal("15.00");
        interestRate = new BigDecimal("0.015");
    }

    @Benchmark
    public BigDecimal computeFormula_Simple() {
        // Source: COMPUTE NEW-BALANCE = BALANCE + AMOUNT
        return balance.add(amount);
    }

    @Benchmark
    public BigDecimal computeFormula_Complex() {
        // Source: COMPUTE NEW-BALANCE = BALANCE + AMOUNT - FEE * INTEREST-RATE
        // COBOL operator precedence: * before +/-, left-to-right for same level
        return balance.add(amount)
            .subtract(fee.multiply(interestRate));
    }

    @Benchmark
    public BigDecimal computeFormula_DivisionWithRounding() {
        // Source: COMPUTE AVG = (AMOUNT1 + AMOUNT2 + AMOUNT3) / 3
        // COBOL: result truncated if no ROUNDED clause
        BigDecimal sum = new BigDecimal("100.00").add(new BigDecimal("200.00"))
            .add(new BigDecimal("300.00"));
        return sum.divide(new BigDecimal("3"), 2, RoundingMode.HALF_UP);
    }

    @Benchmark
    public BigDecimal computeFormula_Chained() {
        // Source: COBOL account settlement — 3 dependent calculations
        BigDecimal newBalance = balance.add(amount);
        BigDecimal feeAmount = newBalance.multiply(new BigDecimal("0.02"));
        BigDecimal availableCredit = new BigDecimal("5000.00")
            .subtract(newBalance)
            .subtract(feeAmount);
        return availableCredit;
    }
}
```

### Benchmark 3: Batch Processing (Page Through Large Dataset)

```java
// BatchProcessingBenchmark.java
// Benchmarks CICS READNEXT cursor → Spring Data paging
// Source: COBOL STARTBR → READNEXT × N → ENDBR pattern

@BenchmarkMode(Mode.Throughput)
@OutputTimeUnit(TimeUnit.SECONDS)
@State(Scope.Benchmark)
public class BatchProcessingBenchmark {

    private CardRepository repository;
    private AccountRepository accountRepository;
    private Pageable pageable;

    @Setup
    public void setup() {
        ApplicationContext context = SpringApplication.run(BenchmarkConfig.class);
        repository = context.getBean(CardRepository.class);
        accountRepository = context.getBean(AccountRepository.class);
        pageable = PageRequest.of(0, 100);
    }

    @Benchmark
    public List<Card> batchBrowse_PageOf100() {
        // Source: COBOL STARTBR → READNEXT × 100 → ENDBR (page size = 100)
        return repository.findAll(pageable).getContent();
    }

    @Benchmark
    public List<Card> batchBrowse_CursorForward() {
        // Source: COBOL STARTBR key >= cursor → READNEXT × 10
        String cursor = "4111110000000000";
        return repository.findAfter(cursor,
            PageRequest.ofSize(10));
    }

    @Benchmark
    public BigDecimal batchAggregate_SumBalances() {
        // Source: COBOL batch job — SORT + COMPUTE total across all accounts
        return repository.sumAllBalances();
    }

    @Benchmark
    @BenchmarkMode(Mode.SingleShotTime)
    @Measurement(iterations = 1, time = 30)
    public long batchProcess_10kRecords() {
        // Source: COBOL JCL batch — process 10,000 records
        AtomicLong processed = new AtomicLong(0);
        String cursor = "0000000000000000";

        while (true) {
            List<Card> page = repository.findAfter(cursor,
                PageRequest.ofSize(200));
            if (page.isEmpty()) break;
            processed.addAndGet(page.size());
            cursor = page.get(page.size() - 1).getCardNumber();
        }

        return processed.get();
    }
}
```

### Benchmark 4: Concurrency / Lock Contention

```java
// ConcurrencyBenchmark.java
// Benchmarks CICS READ UPDATE lock → JPA PESSIMISTIC_WRITE lock
// Source: COBOL EXEC CICS READ UPDATE FILE('CARD') RIDFLD(cardNumber)

@BenchmarkMode(Mode.Throughput)
@OutputTimeUnit(TimeUnit.SECONDS)
@State(Scope.Benchmark)
public class ConcurrencyBenchmark {

    private CardRepository repository;
    private List<String> cardNumbers;

    @Setup
    public void setup() {
        ApplicationContext context = SpringApplication.run(BenchmarkConfig.class);
        repository = context.getBean(CardRepository.class);
        cardNumbers = generateCardNumbers(100);
    }

    @Benchmark
    @Threads(4)
    public Card concurrentPessimisticLock() {
        // Source: COBOL READ UPDATE with concurrent access (4 CICS regions)
        // Java: PESSIMISTIC_WRITE lock — serializes writes, reads unaffected
        String cardNumber = cardNumbers.get(
            ThreadLocalRandom.current().nextInt(cardNumbers.size()));

        Card card = repository.findByIdForUpdate(cardNumber)
            .orElseThrow();
        card.setBalance(card.getBalance().add(BigDecimal.ONE));
        return repository.save(card);
    }

    @Benchmark
    @Threads(4)
    public Card concurrentOptimisticLock() {
        // Source: Compare with @Version optimistic locking for read-heavy workloads
        String cardNumber = cardNumbers.get(
            ThreadLocalRandom.current().nextInt(cardNumbers.size()));

        Card card = repository.findById(cardNumber).orElseThrow();
        card.setBalance(card.getBalance().add(BigDecimal.ONE));
        return repository.save(card); // @Version prevents lost updates
    }
}
```

## Performance SLA Definitions

### SLA Matrix

| SLA Category | Metric | Target | COBOL Baseline | Measurement Method |
|-------------|--------|--------|---------------|-------------------|
| API Response Time | P50 latency | ≤ 100ms | CICS avg transaction time | JMH `@BenchmarkMode(Mode.AverageTime)` × single-thread |
| API Response Time | P95 latency | ≤ 200ms | CICS 95th percentile | Gatling percentile distribution over 5min load test |
| API Response Time | P99 latency | ≤ 500ms | CICS 99th percentile | Gatling simulation with realistic user mix |
| Throughput | Transactions/sec | ≥ 1,000 TPS per pod | CICS TOR discharge rate | JMH `@BenchmarkMode(Mode.Throughput)` |
| Throughput | Concurrent users | ≥ 500 concurrent | CICS MXT (max tasks) setting | Gatling `constantConcurrentUsers(500)` |
| Batch Processing | Records/sec (JCL→Spring Batch) | ≥ 5,000 rec/s | DFSORT throughput | JMH `@BenchmarkMode(Mode.SingleShotTime)` |
| Database | Single-row lookup | ≤ 1ms (cache miss) / ≤ 100µs (cache hit) | VSAM CI read (~2-5ms) | JMH + HikariCP pool metrics |
| Database | Page scan (100 rows) | ≤ 10ms | VSAM sequential read (~50-100ms) | Repository method JMH benchmark |
| Startup Time | Pod ready | ≤ 30s | CICS PLT post-initialization | Kubernetes `readinessProbe.initialDelaySeconds` |
| Startup Time | HikariCP pool ready | ≤ 5s | — | `/actuator/health/readiness` endpoint timing |
| Memory | Heap usage (steady state) | ≤ 512MB (from -Xmx1024m) | CICS DSA ~200MB per region | Micrometer `jvm.memory.used` metric |
| Error Rate | HTTP 5xx rate | ≤ 0.01% | CICS abend rate | Prometheus `http_server_requests_seconds_count{status=~"5.."}` |

### SLA Enforcement in CI/CD

```xml
<!-- pom.xml: Gatling performance SLA check -->
<plugin>
    <groupId>io.gatling</groupId>
    <artifactId>gatling-maven-plugin</artifactId>
    <version>4.8.2</version>
    <configuration>
        <simulationsFolder>src/test/gatling</simulationsFolder>
    </configuration>
    <executions>
        <execution>
            <id>performance-sla-check</id>
            <phase>verify</phase>
            <goals>
                <goal>test</goal>
            </goals>
            <configuration>
                <failOnError>true</failOnError>
            </configuration>
        </execution>
    </executions>
</plugin>
```

## Load Testing Strategy

### Gatling Simulation: Card Update Flow

```scala
// CardUpdateSimulation.scala
// Replicates COCRDUPC card update transaction flow under load

import io.gatling.core.Predef._
import io.gatling.http.Predef._
import scala.concurrent.duration._

class CardUpdateSimulation extends Simulation {

  val httpProtocol = http
    .baseUrl("http://localhost:8080")
    .acceptHeader("application/json")
    .contentTypeHeader("application/json")

  val feeder = csv("card-numbers.csv").random

  val cardUpdateScenario = scenario("Card Update Flow")
    .feed(feeder)
    .exec(http("Login")
      .post("/api/v1/auth/login")
      .body(StringBody("""{"userId":"ADMIN","password":"password"}"""))
      .check(jsonPath("$.token").saveAs("jwtToken")))
    .pause(1)
    .exec(http("Get Update Screen")     // CICS: EIBCALEN=0 (initial display)
      .get("/api/v1/cards/update")
      .header("Authorization", "Bearer ${jwtToken}"))
    .pause(2)
    .exec(http("Update Card")           // CICS: DFHENTER (process)
      .post("/api/v1/cards/update")
      .header("Authorization", "Bearer ${jwtToken}")
      .body(StringBody("""{"cardNumber":"${cardNumber}","holderName":"${holderName}","expiryDate":"2027-12"}"""))
      .check(status.is(200)))
    .pause(1)

  setUp(
    cardUpdateScenario.inject(
      rampUsers(10).during(10.seconds),       // Warm-up
      constantUsersPerSec(50).during(60.seconds), // Steady load
      rampUsersPerSec(50).to(200).during(120.seconds) // Peak test
    )
  ).protocols(httpProtocol)
  .assertions(
    global.responseTime.percentile(95).lte(200),   // P95 ≤ 200ms
    global.responseTime.percentile(99).lte(500),   // P99 ≤ 500ms
    global.successfulRequests.percent.gte(99.5),    // ≥ 99.5% success
    global.failedRequests.count.lte(10)             // ≤ 10 failures
  )
}
```

### Gatling Simulation: Batch Processing

```scala
// TransactionBatchSimulation.scala
// Replicates COTRN00C browse + pagination load

class TransactionBatchSimulation extends Simulation {

  val httpProtocol = http.baseUrl("http://localhost:8080")

  val browseScenario = scenario("Transaction Browse")
    .exec(http("Login").post("/api/v1/auth/login")
      .body(StringBody("""{"userId":"ADMIN","password":"password"}"""))
      .check(jsonPath("$.token").saveAs("token")))
    .exec(http("Browse Page 1")
      .post("/api/v1/transactions/browse")
      .header("Authorization", "Bearer ${token}")
      .body(StringBody("""{"direction":"forward","pageSize":10}""")))
    .pause(1)
    .repeat(5) {  // Browse 5 pages (50 records)
      exec(http("Browse Next Page")
        .post("/api/v1/transactions/browse")
        .header("Authorization", "Bearer ${token}")
        .body(StringBody("""{"direction":"forward","cursor":"${cursor}","pageSize":10}"""))
        .check(jsonPath("$.nextCursor").saveAs("cursor")))
    }

  setUp(
    browseScenario.inject(
      constantConcurrentUsers(100).during(120.seconds)
    )
  ).protocols(httpProtocol)
  .assertions(
    global.responseTime.mean.lte(100),
    global.successfulRequests.percent.gte(99.9)
  )
}
```

## Benchmark Comparison Methodology

### COBOL-vs-Java Apples-to-Apples Protocol

```
BENCHMARK COMPARISON PROTOCOL
=============================

Step 1: Normalize Environment
  COBOL side: Measure on dedicated CICS region, no co-located workloads
  Java side: Measure on dedicated K8s pod, single-replica deployment
  Rule: Same data volume, same data distribution, same query patterns

Step 2: Normalize Metrics
  COBOL "response time" = CICS task dispatch → task complete (DFHRESP)
  Java "response time" = Thread start → method return (JMH measured)
  Rule: Exclude network latency from both (add network model separately)

Step 3: Warm-up Equivalence
  COBOL: 1000 warm-up transactions (CICS program load in cache)
  Java: JMH @Warmup(iterations=3, time=1) + Spring context ready
  Rule: Both fully JIT-compiled / program-resident before measurement

Step 4: Measurement Window
  COBOL: Sample N=10,000 consecutive transactions (SMF type 110 records)
  Java: JMH @Measurement(iterations=5, time=2) × @Threads(1) initial
  Rule: Same sample count (±5%). Exclude first 100 from both.

Step 5: Throughput Comparison
  COBOL: TOR (Transaction Occurrence Rate) from CICS statistics
  Java: JMH ops/s ÷ thread_count (single-thread) × pod_replica_count
  Rule: Report TPS/vCPU to normalize for hardware differences

Step 6: Variance Analysis
  COBOL: Standard deviation from SMF data
  Java: JMH ± error bars
  Rule: Flag if COBOL or Java variance >20% of mean (environmental issue)
```

### Comparison Report Template

```markdown
## Performance Comparison: [Program Name]

| Operation | COBOL (CICS) | Java (JMH) | Delta | Verdict |
|-----------|-------------|-----------|-------|--------|
| Key lookup (cache warm) | X ms avg | Y ms avg | ±Z% | PASS/FAIL |
| Key lookup (cache cold) | X ms avg | Y ms avg | ±Z% | PASS/FAIL |
| Complex COMPUTE | X ms avg | Y ms avg | ±Z% | PASS/FAIL |
| Batch process 10k records | X sec total | Y sec total | ±Z% | PASS/FAIL |
| Concurrent update (4 threads) | X TPS | Y TPS | ±Z% | PASS/FAIL |

Assessment: [PASS if all deltas <20% degradation; INVESTIGATE if 20-50%; FAIL if >50%]

Notes:
- Environment: [COBOL hardware specs] vs [Java K8s node specs]
- Data volume: N records per table
- Measurement date: YYYY-MM-DD
- Tester: [Name]
```

## Production Operations Monitoring

### Prometheus Metrics Endpoints

```yaml
# application.yml — production monitoring
management:
  endpoints:
    web:
      exposure:
        include: health,info,prometheus,metrics
  metrics:
    export:
      prometheus:
        enabled: true
    tags:
      application: ${spring.application.name}
  endpoint:
    health:
      probes:
        enabled: true
      show-details: when-authorized
```

### Grafana Dashboard JSON

Generate `20-performance-benchmarking/grafana-dashboard.json` with panels:
- JVM metrics (heap used/max, GC pause times, thread count)
- Business metrics (transaction rate by endpoint, error rate, response time percentiles)
- Infrastructure metrics (CPU, memory, network I/O by pod)
- Database metrics (active connections, query latency p50/p95/p99, deadlocks)
- Kafka/CDC lag (if CDC strategy from Phase 18)

### Circuit Breaker + Rate Limiting

```yaml
# Resilience4j configuration (production)
resilience4j:
  circuitbreaker:
    instances:
      accountService:
        slidingWindowSize: 10
        minimumNumberOfCalls: 5
        failureRateThreshold: 50
        waitDurationInOpenState: 30s
  retry:
    instances:
      accountService:
        maxAttempts: 3
        waitDuration: 500ms
  ratelimiter:
    instances:
      standardApi:
        limitForPeriod: 100
        limitRefreshPeriod: 1s
        timeoutDuration: 500ms
```

### Graceful Shutdown

```yaml
server:
  shutdown: graceful
spring:
  lifecycle:
    timeout-per-shutdown-phase: 30s
```

## Execution Steps

### Step 1: Configure JMH Benchmarks

Copy all JMH benchmark templates into `src/test/java/com/example/cobolmigration/benchmark/`. Configure benchmark execution via:

```bash
mvn clean package -DskipTests
java -jar target/benchmarks.jar -rf json -rff benchmark-results.json
```

### Step 2: Define Performance SLAs

Finalize the SLA matrix in `performance-sla-definitions.md`. Get sign-off from business stakeholders on acceptable latency and throughput targets.

### Step 3: Write Gatling Simulations

Implement Gatling simulations for all critical transaction flows. Include realistic user think times from CICS monitoring data.

### Step 4: Execute Benchmarks and Collect Results

Run all JMH benchmarks in a dedicated test environment matching production sizing. Store results in `benchmark-results/`.

### Step 5: Execute Load Tests

Run Gatling simulations against the staging environment. Verify all SLA assertions pass.

### Step 6: Compare with COBOL Baseline

If mainframe access is available, measure same operations on COBOL side. Produce comparison reports using the protocol above.

### Step 7: Integrate into CI/CD

Add JMH and Gatling execution to CI/CD pipeline (Phase 12) as optional performance verification stages.

### Step 8: Configure Production Dashboards

Deploy Grafana dashboard JSON. Set up Prometheus alerting rules for SLA violations.

## Quality Gate

- [ ] All JMH benchmark templates compile and execute without errors
- [ ] Performance SLA matrix signed off by business stakeholders
- [ ] Gatling simulations cover all critical transaction flows
- [ ] P95 latency ≤ 200ms on card update, account view, transaction browse
- [ ] Throughput ≥ 1,000 TPS per pod on key lookup benchmark
- [ ] Batch processing ≥ 5,000 records/second
- [ ] COBOL-vs-Java comparison report completed (if mainframe access available)
- [ ] No performance regression >20% from baseline
- [ ] Prometheus metrics endpoint enabled and scraped
- [ ] Grafana dashboard deployed with all monitoring panels
- [ ] Circuit breaker + rate limiting configured and tested
- [ ] Graceful shutdown working (no dropped transactions during pod termination)
- [ ] `_state-snapshot.json` updated to `{'phase':20,'status':'complete'}`
