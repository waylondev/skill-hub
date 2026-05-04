# Phase 14: Developer Onboarding & Quick Start

## Objective

Provide a frictionless onboarding experience for Java developers joining the migration project. Developers must be able to clone the repository, start all dependent services locally, explore the API, and debug the application — all within 15 minutes of first checkout. No prior COBOL knowledge required.

## Input

- Phase 8: Deliverable Specifications (application architecture)
- Phase 9: Generated Code (complete source tree)
- Phase 10: Frontend Migration (if React/Angular frontend exists)
- Phase 13: Docker & Kubernetes (docker-compose configuration)

## Deliverables

- `14-quick-start/README-onboarding.md` — Developer onboarding guide
- `14-quick-start/docker-compose.yml` — Full local development stack
- `14-quick-start/postman-collection.json` — API sample requests collection
- `14-quick-start/curl-samples.md` — Curl command reference for all endpoints
- `14-quick-start/ide-configuration.md` — IDE setup guide (IntelliJ IDEA / VS Code / Eclipse)
- `14-quick-start/debugging-guide.md` — Debugging tips and common issues

## Quick Start Commands

```bash
# 1. Clone and start all services
git clone [repo-url] && cd [project-name]
docker-compose up -d                    # Start PostgreSQL + Redis + App

# 2. Build and run application
./mvnw spring-boot:run                  # Start application

# 3. Explore APIs
open http://localhost:8080/swagger-ui   # API documentation (SpringDoc OpenAPI)
open http://localhost:8080/actuator     # Actuator endpoints (health, metrics, env)
```

## Local Development Environment Setup

### Prerequisites

| Tool | Version | Purpose | Installation Check |
|------|---------|---------|-------------------|
| JDK | 21 (Temurin) | Java compilation & runtime | `java -version` |
| Maven Wrapper | 3.9+ | Build & dependency management | `./mvnw --version` |
| Docker Desktop | 24+ | Containerized local services | `docker --version` |
| Docker Compose | v2 | Multi-service orchestration | `docker compose version` |
| Git | 2.40+ | Source control | `git --version` |
| IntelliJ IDEA | 2024.1+ | Primary IDE (recommended) | Community Edition suffices |

### Docker Compose Stack

```yaml
version: '3.8'
services:
  postgres:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: cobol_migration
      POSTGRES_USER: appuser
      POSTGRES_PASSWORD: devpassword
    ports:
      - "5432:5432"
    volumes:
      - pgdata:/var/lib/postgresql/data
      - ./src/main/resources/db/migration:/docker-entrypoint-initdb.d
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U appuser -d cobol_migration"]
      interval: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      retries: 5

  zipkin:
    image: openzipkin/zipkin:latest
    ports:
      - "9411:9411"

  app:
    build: .
    ports:
      - "8080:8080"
    environment:
      SPRING_PROFILES_ACTIVE: dev
      SPRING_DATASOURCE_URL: jdbc:postgresql://postgres:5432/cobol_migration
      SPRING_DATASOURCE_USERNAME: appuser
      SPRING_DATASOURCE_PASSWORD: devpassword
      SPRING_DATA_REDIS_HOST: redis
      MANAGEMENT_ZIPKIN_TRACING_ENDPOINT: http://zipkin:9411/api/v2/spans
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy

volumes:
  pgdata:
```

### Application Run Profiles

| Profile | Database | Redis | Tracing | Logging | Use Case |
|---------|----------|-------|---------|---------|----------|
| `dev` | Local Docker PostgreSQL | Local Docker Redis | Zipkin (localhost:9411) | DEBUG | Daily development |
| `dev-h2` | H2 in-memory | None | None | DEBUG | Quick unit/integration test runs |
| `staging` | Staging RDS | Staging ElastiCache | Production Zipkin | INFO | Pre-release validation |
| `production` | Production RDS | Production ElastiCache | Production Zipkin | WARN | Live traffic |

## IDE Configuration Recommendations

### IntelliJ IDEA (Recommended)

| Configuration | Value | How to Set |
|--------------|-------|-----------|
| Project SDK | JDK 21 (Temurin) | File → Project Structure → SDK |
| Annotation Processors | Enable Lombok | Settings → Build → Compiler → Annotation Processors |
| Code Style | Google Java Style | Settings → Editor → Code Style → Import Scheme |
| CheckStyle Plugin | `google_checks.xml` | Plugins → CheckStyle-IDEA → Configuration File |
| SonarLint | Enable with connected mode | Plugins → SonarLint → Bind to SonarQube server |
| Run Configurations | Spring Boot + dev profile | Run → Edit Configurations → Active profiles: `dev` |

### VS Code

```json
{
  "java.configuration.runtimes": [
    { "name": "JavaSE-21", "path": "/path/to/jdk-21" }
  ],
  "java.compile.nullAnalysis.mode": "automatic",
  "spring-boot.ls.java.heap": "512m",
  "java.jdt.ls.vmargs": "-XX:+UseZGC -Xmx2G"
}
```

### Recommended Plugins (All IDEs)

- **Lombok**: Required for `@Data`, `@Builder`, `@Slf4j` annotations to resolve in IDE
- **SonarLint**: Real-time code quality feedback aligned with SonarQube quality gate
- **Spring Boot Tools**: YAML autocomplete, actuator endpoint navigation, bean dependency graph
- **Docker**: Dockerfile syntax highlighting, docker-compose service management
- **CheckStyle**: Enforce Google Java Style Guide conventions

## API Exploration

### SpringDoc OpenAPI (Swagger UI)

Navigate to `http://localhost:8080/swagger-ui` for interactive API documentation. All endpoints from Phase 8 controllers are documented with:
- Request/Response schemas (derived from DTOs)
- Authentication requirements (JWT Bearer token)
- Example request bodies
- HTTP status codes

### Postman Collection

Import `14-quick-start/postman-collection.json` into Postman. The collection includes:
- Pre-request script to obtain JWT token from `/api/v1/auth/login`
- Environment variables for `baseUrl`, `token`, `userId`
- Folders organized by resource (Cards, Accounts, Users, Transactions)

### Curl Samples

```bash
# Authentication
curl -X POST http://localhost:8080/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"userId":"ADMIN","password":"password"}'

# Store JWT token
TOKEN=$(curl -s -X POST http://localhost:8080/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"userId":"ADMIN","password":"password"}' | jq -r '.token')

# Browse Cards (GET — initial screen)
curl -X GET http://localhost:8080/api/v1/cards/browse \
  -H "Authorization: Bearer $TOKEN"

# Update Card (POST — ENTER key equivalent)
curl -X POST http://localhost:8080/api/v1/cards/update \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"cardNumber":"4111111111111111","holderName":"JOHN DOE","expiryDate":"2026-12"}'
```

## Debugging Tips

### Debugging COBOL→Java Translation Issues

1. **Locate the source**: Every Java class/method has a `// Source: [program.cbl], lines [N]-[M]` comment. Navigate to the referenced COBOL program to understand original intent.

2. **Trace the call chain**: Enable DEBUG logging and follow the request path:
   ```
   Controller → Service → Repository → Database
   ```
   Compare against CICS flow:
   ```
   RECEIVE MAP → PROCEDURE DIVISION → CICS READ/WRITE → VSAM
   ```

3. **Compare data**: Run the old COBOL program against test data and compare output with the new Java service. Use the test matrix from Phase 7 for known input/output pairs.

### Common Pitfalls

| Issue | Symptom | Resolution |
|-------|---------|-----------|
| COMP-3 precision loss | BigDecimal values off by 0.01 | Check `@Column(precision, scale)` matches PIC clause exactly |
| CICS cursor mismatch | Pagination returns wrong records | Verify `findAfter`/`findBefore` cursor encoding (EBCDIC vs. UTF-8 sort order) |
| Concurrency lost update | Stale data written on concurrent access | Ensure `@Lock(PESSIMISTIC_WRITE)` on all UPDATE paths |
| ASCII/EBCDIC encoding | Garbled text in migrated fields | Use `EBCDIC→UTF-8 converter` from Phase 16 toolchain |

### Remote Debugging

```bash
# Start application with debug port
java -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5005 \
  -jar target/app.jar

# IntelliJ: Run → Attach to Process → localhost:5005
```

## Execution Steps

### Step 1: Write Onboarding Guide

Create `README-onboarding.md` covering all sections above. Focus on "15-minute first run" experience.

### Step 2: Build Docker Compose

Write `docker-compose.yml` with PostgreSQL, Redis, Zipkin, and the application. Include health checks so dependent services wait for upstream readiness.

### Step 3: Generate Postman Collection

Export all API endpoints from SpringDoc OpenAPI spec into a Postman collection JSON. Include authentication pre-request scripts.

### Step 4: Generate Curl Samples

Write `curl-samples.md` with ready-to-paste commands for every endpoint, including authentication flow.

### Step 5: Write IDE Configuration Guide

Create `ide-configuration.md` with step-by-step screenshots (or textual instructions) for IntelliJ IDEA, VS Code, and Eclipse.

### Step 6: Write Debugging Guide

Create `debugging-guide.md` covering common COBOL→Java debugging scenarios, remote debugging setup, and database query debugging via Actuator.

## Quality Gate

- [ ] `docker-compose up -d` starts all services successfully (PostgreSQL, Redis, App)
- [ ] Swagger UI accessible at `http://localhost:8080/swagger-ui`
- [ ] All API endpoints documented with request/response schemas
- [ ] Postman collection importable and runnable against local instance
- [ ] Curl samples all copy-paste-runnable without modification
- [ ] IDE setup guide covers IntelliJ IDEA (primary) + VS Code (secondary)
- [ ] Lombok annotation processing documented and verified working in IDE
- [ ] Remote debugging documented (attach on port 5005)
- [ ] Common COBOL→Java debugging pitfalls documented with resolution steps
- [ ] New developer can complete full setup + first API call within 15 minutes
- [ ] `_state-snapshot.json` updated to `{'phase':14,'status':'complete'}`
