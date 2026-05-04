# Phase 19: Automated Regression Testing Framework

## Objective

Establish a comprehensive automated regression testing framework that verifies the migrated Java application produces identical results to the original COBOL system. The framework must detect regressions before they reach staging, provide rapid feedback in CI/CD, and produce auditable test evidence for compliance.

## Input

- Phase 5: Logic Extraction — all business rules and expected behaviors
- Phase 7: Testing Matrix — test case inventory and categories
- Phase 8: DTO Specifications — request/response schemas
- Phase 8: REST API Specification — all endpoint contracts
- Phase 9: Generated Code — complete service and controller implementations
- Phase 12: CI/CD Pipeline — pipeline stages for test execution

## Deliverables

- `19-regression-testing/test-framework-selection.md` — Framework stack and rationale
- `19-regression-testing/golden-test-baseline/` — Golden test baseline data
- `19-regression-testing/test-suite-organization.md` — Test suite structure and naming
- `19-regression-testing/test-data-management.md` — Test data generation and lifecycle
- `19-regression-testing/cicd-test-orchestration.md` — CI/CD integration and parallelism
- `19-regression-testing/reporting-standards.md` — Allure, JaCoCo, and report templates
- `19-regression-testing/performance-regression-detection.md` — Performance regression rules

## Test Automation Framework Selection

### Framework Stack

| Layer | Tool | Version | Purpose |
|-------|------|---------|---------|
| Test Runner | JUnit 5 (Jupiter) | 5.10+ | Test execution, parameterized tests, tagging |
| Mocking | Mockito | 5.x | Service layer mocks, behavior verification |
| Integration Testing | Spring Boot Test | 3.x | Full Spring context tests, `@SpringBootTest` |
| Container Management | Testcontainers | 1.19+ | PostgreSQL, Redis containers for integration tests |
| Contract Testing | Pact JVM (Consumer/Provider) | 4.6+ | API contract verification between services |
| API Testing | REST Assured | 5.4+ | HTTP endpoint testing with JSON validation |
| Database Testing | Flyway + `@Sql` | — | Schema migration and seed data management |
| Code Coverage | JaCoCo | 0.8+ | Line/branch/complexity coverage |
| Test Reporting | Allure Framework | 2.24+ | Rich test reports with attachments and history |
| Golden Baseline | Custom Comparator | — | COBOL-vs-Java output comparison |

### Dependency Configuration

```xml
<!-- pom.xml — Test dependencies -->
<dependencies>
    <!-- JUnit 5 -->
    <dependency>
        <groupId>org.junit.jupiter</groupId>
        <artifactId>junit-jupiter</artifactId>
        <scope>test</scope>
    </dependency>

    <!-- Testcontainers -->
    <dependency>
        <groupId>org.testcontainers</groupId>
        <artifactId>testcontainers</artifactId>
        <version>1.19.3</version>
        <scope>test</scope>
    </dependency>
    <dependency>
        <groupId>org.testcontainers</groupId>
        <artifactId>postgresql</artifactId>
        <version>1.19.3</version>
        <scope>test</scope>
    </dependency>

    <!-- REST Assured -->
    <dependency>
        <groupId>io.rest-assured</groupId>
        <artifactId>rest-assured</artifactId>
        <scope>test</scope>
    </dependency>

    <!-- Pact -->
    <dependency>
        <groupId>au.com.dius.pact.consumer</groupId>
        <artifactId>junit5</artifactId>
        <version>4.6.9</version>
        <scope>test</scope>
    </dependency>
</dependencies>
```

## Golden Test Baseline Automation

### Concept

Golden tests compare Java output against known COBOL output for the same inputs. The COBOL outputs are captured once and stored as immutable "golden files" in the repository.

### COBOL Golden Baseline Capture

```bash
# Phase 1: Capture COBOL golden output (run on mainframe once)
# For each program, run known test inputs and save outputs

for program in COSGN00C COCRDUPC COACTVWC COTRN00C; do
  # Submit COBOL program with test input dataset
  //RUNPROG  JOB
  //STEP1    EXEC PGM=$program
  //INPUT    DD DISP=SHR,DSN=TEST.INPUT($program)
  //OUTPUT   DD DISP=(NEW,CATLG),DSN=GOLDEN.OUTPUT($program)

  # Convert EBCDIC output → UTF-8 golden file
  java EbcdicToUtf8Converter \
    "//'GOLDEN.OUTPUT($program)'" \
    "golden-baseline/$program.json"
done
```

### Golden Test Comparator

```java
// GoldenBaselineComparator.java
// Compares Java service output against COBOL golden baseline

@SpringBootTest
@AutoConfigureMockMvc
public abstract class GoldenBaselineTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    protected void assertMatchesGolden(
            String testId,
            String requestJson,
            String goldenFilePath) throws Exception {

        MvcResult result = mockMvc.perform(post("/api/v1/...")
                .contentType(MediaType.APPLICATION_JSON)
                .content(requestJson))
            .andExpect(status().isOk())
            .andReturn();

        String javaOutput = result.getResponse().getContentAsString();
        String goldenOutput = Files.readString(Path.of(goldenFilePath));

        JsonNode javaNode = objectMapper.readTree(javaOutput);
        JsonNode goldenNode = objectMapper.readTree(goldenOutput);

        List<Difference> diffs = compareNodes(javaNode, goldenNode, "");
        if (!diffs.isEmpty()) {
            String report = diffs.stream()
                .map(Difference::toString)
                .collect(Collectors.joining("\n"));
            fail("Golden baseline mismatch for " + testId + ":\n" + report);
        }
    }

    private List<Difference> compareNodes(JsonNode actual, JsonNode expected,
                                           String path) {
        List<Difference> diffs = new ArrayList<>();

        if (actual.isObject() && expected.isObject()) {
            Set<String> keys = new HashSet<>();
            expected.fieldNames().forEachRemaining(keys::add);
            actual.fieldNames().forEachRemaining(keys::add);

            for (String key : keys) {
                String newPath = path + "." + key;
                if (!actual.has(key)) {
                    diffs.add(new Difference(newPath, "MISSING", null, expected.get(key)));
                } else if (!expected.has(key)) {
                    diffs.add(new Difference(newPath, "EXTRA", actual.get(key), null));
                } else {
                    diffs.addAll(compareNodes(actual.get(key), expected.get(key), newPath));
                }
            }
        } else if (!actual.equals(expected)) {
            diffs.add(new Difference(path, "VALUE_MISMATCH", actual, expected));
        }

        return diffs;
    }

    record Difference(String path, String type, JsonNode actual, JsonNode expected) {
        @Override
        public String toString() {
            return String.format("  [%s] %s: actual=%s, expected=%s",
                type, path, actual, expected);
        }
    }
}
```

### Concrete Golden Test Example

```java
// CardUpdateGoldenTest.java
// Source: COCRDUPC.cbl — Card Update program
@DisplayName("Golden: COCRDUPC Card Update")
class CardUpdateGoldenTest extends GoldenBaselineTest {

    @Test
    @DisplayName("GOLDEN-002: Update active card with valid data")
    void updateActiveCard() throws Exception {
        assertMatchesGolden(
            "GOLDEN-002",
            """
            {
                "cardNumber": "4111111111111111",
                "holderName": "JOHN DOE",
                "expiryDate": "2027-12",
                "creditLimit": "5000.00"
            }
            """,
            "golden-baseline/COCRDUPC/update-active-card.json"
        );
    }

    @Test
    @DisplayName("GOLDEN-003: Update blocked card (should reject)")
    void updateBlockedCard() throws Exception {
        MvcResult result = mockMvc.perform(post("/api/v1/cards/update")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                    {
                        "cardNumber": "5555555555555555",
                        "holderName": "JANE SMITH",
                        "expiryDate": "2026-06"
                    }
                    """))
            .andExpect(status().isConflict())  // COBOL: RESP=106
            .andReturn();

        assertMatchesGolden("GOLDEN-003",
            result.getResponse().getContentAsString(),
            "golden-baseline/COCRDUPC/update-blocked-card.json");
    }
}
```

## CI/CD Test Orchestration

### Test Pyramid and Execution Order

```
                          ┌─────────┐
                          │  E2E    │  ← Gatling/Playwright (manual trigger)
                          │  Tests  │
                          └────┬────┘
                        ┌──────┴──────┐
                        │   Golden    │  ← Phase 19: COBOL vs Java comparison
                        │   Tests     │     Run in CI, parallel with integration
                        └──────┬──────┘
                  ┌────────────┴────────────┐
                  │   Integration Tests     │  ← Testcontainers, REST Assured
                  │   (Phase 19)            │     Run in CI, max 3 min
                  └────────────┬────────────┘
            ┌──────────────────┴──────────────────┐
            │         Contract Tests (Pact)        │  ← Consumer + Provider
            │                                      │     Run in CI, max 1 min
            └──────────────────┬──────────────────┘
      ┌────────────────────────┴────────────────────────┐
      │               Unit Tests (JUnit 5)              │  ← Fast, no I/O
      │                                                  │     Run in CI, max 30s
      └─────────────────────────────────────────────────┘
```

### Maven Test Profiles

```xml
<!-- pom.xml profiles for test orchestration -->
<profiles>
    <profile>
        <id>unit</id>
        <properties>
            <test.tags>unit</test.tags>
        </properties>
    </profile>
    <profile>
        <id>integration</id>
        <properties>
            <test.tags>integration</test.tags>
        </properties>
    </profile>
    <profile>
        <id>golden</id>
        <properties>
            <test.tags>golden</test.tags>
        </properties>
    </profile>
    <profile>
        <id>all-tests</id>
        <properties>
            <test.tags>unit | integration | golden</test.tags>
        </properties>
    </profile>
</profiles>
```

```bash
# CI/CD Pipeline: Progressive test execution
mvn test -Punit                         # Fast feedback (<30s)
mvn test -Pintegration                  # Medium (<3min)
mvn test -Pgolden                       # Golden validation (<5min)
mvn verify -Pall-tests                  # Full suite with coverage
```

### GitHub Actions Test Matrix

```yaml
# .github/workflows/test-matrix.yml
name: Test Matrix
on: [push, pull_request]

jobs:
  unit-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with: { java-version: '21', distribution: 'temurin' }
      - name: Unit Tests
        run: mvn test -Punit
      - name: Publish Results
        uses: dorny/test-reporter@v1
        with:
          name: Unit Tests
          path: '**/TEST-*.xml'
          reporter: java-junit

  integration-tests:
    needs: unit-tests
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:15-alpine
        env: { POSTGRES_DB: testdb, POSTGRES_USER: test, POSTGRES_PASSWORD: test }
        ports: ['5432:5432']
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with: { java-version: '21', distribution: 'temurin' }
      - name: Integration Tests
        run: mvn test -Pintegration
        env:
          SPRING_DATASOURCE_URL: jdbc:postgresql://localhost:5432/testdb

  golden-tests:
    needs: unit-tests
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:15-alpine
        env: { POSTGRES_DB: testdb, POSTGRES_USER: test, POSTGRES_PASSWORD: test }
        ports: ['5432:5432']
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with: { java-version: '21', distribution: 'temurin' }
      - name: Golden Tests
        run: mvn test -Pgolden
      - name: Archive Golden Report
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: golden-diffs
          path: build/reports/golden-diffs/
```

## Test Data Management Strategy

### Test Data Generation

```java
// TestDataFactory.java
// Generates realistic test data reflecting COBOL data characteristics

public class TestDataFactory {

    private static final Faker faker = new Faker();

    public static Card createCard(CardStatus status) {
        return Card.builder()
            .cardNumber(generateCardNumber())
            .accountId("ACCT-" + generateNumeric(10))
            .holderName(faker.name().fullName().toUpperCase())
            .expiryDate(LocalDate.now().plusYears(2))
            .creditLimit(new BigDecimal("5000.00"))
            .balance(BigDecimal.ZERO)
            .status(status.name())
            .build();
    }

    public static List<Card> createCardBatch(int count, CardStatus status) {
        return IntStream.range(0, count)
            .mapToObj(i -> createCard(status))
            .toList();
    }

    private static String generateCardNumber() {
        // Source: COBOL PIC 9(16) card numbers with Luhn checksum
        return "411111" + generateNumeric(9) + luhnCheckDigit();
    }
}
```

### Test Data Lifecycle

```java
// TestDataLifecycleExtension.java
// JUnit 5 extension managing test data per test method

public class TestDataLifecycleExtension implements
        BeforeEachCallback, AfterEachCallback {

    private static final PostgreSQLContainer<?> POSTGRES =
        new PostgreSQLContainer<>("postgres:15-alpine")
            .withDatabaseName("testdb")
            .withUsername("test")
            .withPassword("test");

    static {
        POSTGRES.start();
        System.setProperty("spring.datasource.url", POSTGRES.getJdbcUrl());
        System.setProperty("spring.datasource.username", POSTGRES.getUsername());
        System.setProperty("spring.datasource.password", POSTGRES.getPassword());
    }

    @Override
    public void beforeEach(ExtensionContext context) {
        // Each test gets a clean slate: truncate → seed → validate
        TestData testData = context.getTestMethod()
            .flatMap(m -> Optional.ofNullable(m.getAnnotation(Seed.class)))
            .map(seed -> loadSeedData(seed.value()))
            .orElse(TestData.EMPTY);

        context.getStore(NAMESPACE).put("testData", testData);
    }

    @Override
    public void afterEach(ExtensionContext context) {
        // Clean up test-specific data
        truncateAllTables();
    }

    @Retention(RetentionPolicy.RUNTIME)
    @Target(ElementType.METHOD)
    public @interface Seed {
        String value();  // Path to JSON seed file
    }
}
```

## Regression Test Suite Organization

### Suite Structure

```
src/test/java/com/example/cobolmigration/
├── unit/
│   ├── service/
│   │   ├── CardUpdateServiceTest.java        # Source: COCRDUPC.cbl
│   │   ├── AccountViewServiceTest.java       # Source: COACTVWC.cbl
│   │   └── TransactionBrowseServiceTest.java # Source: COTRN00C.cbl
│   ├── util/
│   │   ├── Comp3ConverterTest.java           # Source: Phase 16 utility
│   │   └── ValidationUtilsTest.java
│   └── domain/
│       ├── CardTest.java
│       └── AccountTest.java
├── integration/
│   ├── repository/
│   │   ├── CardRepositoryTest.java
│   │   └── AccountRepositoryTest.java
│   ├── controller/
│   │   ├── CardUpdateControllerTest.java
│   │   └── AccountViewControllerTest.java
│   └── batch/
│       └── DailyBatchJobTest.java
├── golden/
│   ├── CardUpdateGoldenTest.java
│   ├── AccountViewGoldenTest.java
│   └── SignOnGoldenTest.java
├── contract/
│   ├── consumer/
│   │   └── CardServiceConsumerPactTest.java
│   └── provider/
│       └── CardServiceProviderPactTest.java
└── e2e/
    └── CriticalPathE2ETest.java

src/test/resources/
├── golden-baseline/
│   ├── COSGN00C/
│   │   ├── login-success.json
│   │   └── login-invalid-user.json
│   ├── COCRDUPC/
│   │   ├── update-active-card.json
│   │   └── update-blocked-card.json
│   └── COTRN00C/
│       ├── browse-page-1.json
│       └── browse-page-2.json
├── seed-data/
│   ├── card-test-data.json
│   └── account-test-data.json
├── db/migration/
│   └── V1__test_schema.sql
└── sql/
    └── cleanup.sql
```

### Test Tagging Convention

```java
@Tag("unit")
@Tag("service")
@DisplayName("COCRDUPC: Card Update Service")
class CardUpdateServiceTest { }

@Tag("integration")
@Tag("controller")
@Tag("cards")
@DisplayName("Card Update Controller Integration")
class CardUpdateControllerTest { }

@Tag("golden")
@Tag("cards")
@DisplayName("Golden: COCRDUPC Card Update")
class CardUpdateGoldenTest { }
```

## Reporting Standards

### Allure Report Configuration

```xml
<!-- pom.xml: Allure reporting -->
<reporting>
    <plugins>
        <plugin>
            <groupId>io.qameta.allure</groupId>
            <artifactId>allure-maven</artifactId>
            <version>2.12.0</version>
        </plugin>
    </plugins>
</reporting>
```

```java
// Allure annotations for rich reports
@Epic("Card Management")
@Feature("Card Update")
@Story("COCRDUPC Migration")
class CardUpdateGoldenTest {

    @Test
    @Severity(SeverityLevel.CRITICAL)
    @Description("Validates COCRDUPC produces identical output to COBOL")
    @Link(name = "COCRDUPC.cbl", url = "https://github.com/.../COCRDUPC.cbl")
    void updateActiveCard() {
        // Test body
        Allure.step("Load golden baseline for active card update");
        Allure.step("Execute Java service with same input");
        Allure.step("Compare JSON output field-by-field");
    }
}
```

### JaCoCo Coverage Configuration

```xml
<plugin>
    <groupId>org.jacoco</groupId>
    <artifactId>jacoco-maven-plugin</artifactId>
    <version>0.8.11</version>
    <executions>
        <execution>
            <goals>
                <goal>prepare-agent</goal>
            </goals>
        </execution>
        <execution>
            <id>report</id>
            <phase>verify</phase>
            <goals>
                <goal>report</goal>
            </goals>
        </execution>
        <execution>
            <id>coverage-check</id>
            <phase>verify</phase>
            <goals>
                <goal>check</goal>
            </goals>
            <configuration>
                <rules>
                    <rule>
                        <element>BUNDLE</element>
                        <limits>
                            <limit>
                                <counter>LINE</counter>
                                <value>COVEREDRATIO</value>
                                <minimum>0.80</minimum>
                            </limit>
                            <limit>
                                <counter>BRANCH</counter>
                                <value>COVEREDRATIO</value>
                                <minimum>0.70</minimum>
                            </limit>
                        </limits>
                    </rule>
                </rules>
            </configuration>
        </execution>
    </executions>
</plugin>
```

### Test Reporting Dashboard (Grafana/Allure)

```
Key metrics tracked:
├── Test pass rate (last 24h): target ≥ 99.5%
├── Test execution time (p50/p95/median)
├── Flaky test count (failed once, passed on retry)
├── Code coverage trend (LINE + BRANCH over last 30d)
├── Golden test pass rate (mismatch trend)
└── Performance regression alerts (latency + throughput vs. baseline)
```

## Performance Regression Detection

### Latency Regression Rule

```java
// PerformanceRegressionTest.java
// Detects performance regressions against Phase 20 baseline

@SpringBootTest
@AutoConfigureMockMvc
class PerformanceRegressionTest {

    private static final Duration P95_THRESHOLD = Duration.ofMillis(200);
    private static final double REGRESSION_FACTOR = 1.20; // 20% degradation = fail

    @Test
    void cardUpdateLatencyRegression() {
        List<Long> latencies = new ArrayList<>();
        int iterations = 100;

        for (int i = 0; i < iterations; i++) {
            long start = System.nanoTime();
            executeCardUpdate();
            latencies.add(System.nanoTime() - start);
        }

        Collections.sort(latencies);
        int p95Index = (int) (iterations * 0.95);
        double p95Ms = latencies.get(p95Index) / 1_000_000.0;

        double baselineP95 = loadBaseline("card-update-p95").p95ms();
        double threshold = baselineP95 * REGRESSION_FACTOR;

        assertThat(p95Ms)
            .as("P95 latency regression detected")
            .isLessThanOrEqualTo(threshold);
    }

    record Baseline(double p95ms, double avgMs, double tps) {}

    private Baseline loadBaseline(String testName) {
        // Load from Phase 20 benchmark results
        return objectMapper.readValue(
            Path.of("20-performance-benchmarking/results/" + testName + ".json"),
            Baseline.class
        );
    }
}
```

### Throughput Regression Check

```java
@Test
void cardUpdateThroughputRegression() {
    int durationSeconds = 5;
    AtomicInteger count = new AtomicInteger(0);
    Instant end = Instant.now().plusSeconds(durationSeconds);

    while (Instant.now().isBefore(end)) {
        executeCardUpdate();
        count.incrementAndGet();
    }

    double tps = count.get() / (double) durationSeconds;
    double baselineTps = loadBaseline("card-update-throughput").tps();
    double threshold = baselineTps * 0.80; // Cannot drop below 80% of baseline

    assertThat(tps)
        .as("Throughput regression detected: %.1f tps vs baseline %.1f tps", tps, baselineTps)
        .isGreaterThanOrEqualTo(threshold);
}
```

## Execution Steps

### Step 1: Select Framework Stack

Confirm all test dependencies in `pom.xml`. Verify Testcontainers Docker availability in CI environment.

### Step 2: Capture Golden Baselines

Run all COBOL programs with known test inputs. Capture outputs as golden JSON files. Store in `src/test/resources/golden-baseline/`.

### Step 3: Build Test Suite Structure

Organize tests into the five layers: unit, integration, golden, contract, e2e. Tag all tests for CI/CD matrix execution.

### Step 4: Create Test Data Management

Implement `TestDataFactory` and `TestDataLifecycleExtension`. Each test method starts with a clean database state.

### Step 5: Configure CI/CD Test Orchestration

Implement the GitHub Actions test matrix (or Jenkins parallel stages). Unit tests block integration tests on failure.

### Step 6: Set Up Reporting

Configure Allure report generation, JaCoCo coverage checks, and test result publishing to CI/CD dashboard.

### Step 7: Implement Performance Regression Detection

Wire latency and throughput regression checks into the golden test phase. Fail CI/CD if regression >20%.

### Step 8: Execute Full Regression Suite

Run `mvn verify -Pall-tests`. Verify all 5 test layers pass. Check Allure report for anomalies.

## Quality Gate

- [ ] All 5 test layers (unit, integration, golden, contract, e2e) defined and passing
- [ ] Testcontainers used for all integration tests (no H2 for DB-dependent tests)
- [ ] Golden baseline tests passing for all migrated COBOL programs
- [ ] Allure report generated with per-test pass/fail, severity, and attachments
- [ ] JaCoCo line coverage ≥ 80%, branch coverage ≥ 70%
- [ ] CI/CD test matrix runs in <10 minutes (parallel execution)
- [ ] Test data lifecycle ensures clean state per test method
- [ ] Taggable test selection enables fast feedback (<30s unit, <3min integration)
- [ ] Performance regression detection wired into CI/CD (fail on >20% degradation)
- [ ] Flaky test detection enabled (retry once, flag if fails both times)
- [ ] Golden baseline files immutable (stored in VCS, changes require PR review)
- [ ] `_state-snapshot.json` updated to `{'phase':19,'status':'complete'}`
