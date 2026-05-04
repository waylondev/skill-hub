# Phase 6: Architecture Reconstruction + Dependency Graph + Inter-Service Protocol

## Objective

Reconstruct the as-is architecture from source code analysis. Produce detailed Mermaid diagrams showing program dependencies, data flows, microservice boundary recommendations, **inter-service communication protocols**, and JCL-to-Spring Batch mapping.

## Input

- Phase 1-5 analysis output
- All COBOL programs, COPYBOOKs, VSAM structures, JCL files

## Deliverables

### `06-architecture/architecture-diagrams.md`

```markdown
# Architecture Reconstruction

## Current State Architecture

```mermaid
graph TD
    subgraph "CICS Region"
        PGM1[PGM1 - Program 1]
        PGM2[PGM2 - Program 2]
        PGM3[PGM3 - Program 3]
    end

    subgraph "VSAM Files"
        F1[FILE1]
        F2[FILE2]
        F3[FILE3]
    end

    subgraph "External"
        EXT1[External System 1]
    end

    PGM1 -->|READ/WRITE| F1
    PGM1 -->|LINK| PGM2
    PGM2 -->|READ| F2
    PGM2 -->|READ| F3
    PGM3 -->|CALL| EXT1
```

## Target State Architecture

```mermaid
graph TD
    subgraph "Spring Boot Microservices"
        SVC1[Account Service]
        SVC2[Card Service]
        SVC3[Payment Service]
    end

    subgraph "PostgreSQL"
        DB[(Database)]
    end

    subgraph "Infrastructure"
        GW[API Gateway]
        MQ[Message Queue]
        CACHE[(Redis Cache)]
    end

    Client --> GW
    GW --> SVC1
    GW --> SVC2
    GW --> SVC3
    SVC1 --> DB
    SVC2 --> DB
    SVC3 --> DB
    SVC3 --> MQ
    SVC1 --> CACHE
    SVC2 --> CACHE
```

## Program Dependency Matrix

| From/To | PGM1 | PGM2 | PGM3 | FILE1 | FILE2 | FILE3 |
|---------|------|------|------|-------|-------|-------|
| PGM1    | -    | LINK | -    | R/W   | -     | -     |
| PGM2    | -    | -    | -    | -     | R     | R     |
| PGM3    | -    | -    | -    | -     | -     | -     |

## Microservice Boundary Recommendations

| Service | Programs | VSAM Files | Description | Dependencies |
|---------|----------|------------|-------------|-------------|
| [Name] | [list] | [list] | [purpose] | [list] |

## Hybrid Architecture (Migration Transit)

```mermaid
graph LR
    subgraph "New (Spring Boot)"
        SVC1[Account Service]
        SVC2[Card Service]
    end
    subgraph "Legacy (CICS)"
        PGMB[CICS Program B]
    end
    subgraph "Middleware"
        SYNC[Data Sync]
    end
    SVC1 --> SYNC
    SVC2 --> SYNC
    SYNC --> PGMB
```

## Inter-Service Communication Protocol (NEW — Required)

### Service-to-Service Dependency Map

| Consumer Service | Provider Service | Data Needed | Protocol | Endpoint/Topic | Reason |
|-----------------|-----------------|------------|----------|---------------|--------|
| transaction-service | card-service | Card validation | REST (synchronous) | GET /api/v1/cards/{id}/validate | Card exists? Active? |
| transaction-service | account-service | Account balance | REST (synchronous) | GET /api/v1/accounts/{id}/balance | Balance check before debit |
| auth-service | admin-service | User profile | REST (synchronous) | GET /api/v1/admin/users/{id} | User lookup during login |
| card-service | account-service | Account status | REST (synchronous) | GET /api/v1/accounts/{id}/status | Verify account active |
| batch-service | transaction-service | Daily transactions | Event (async) | topic: daily-transactions-ready | Batch trigger |
| batch-service | account-service | Account updates | Event (async) | topic: account-updates | Interest calculation |

### Protocol Decision Rules

| Scenario | Protocol | Rationale | COBOL Equivalent |
|----------|----------|-----------|-----------------|
| Caller needs immediate response | REST (synchronous) | Blocking call, need data now | CICS LINK/XCTL |
| Fire-and-forget notification | Message Queue (async) | Non-blocking, eventual consistency | MQ PUT |
| Batch data handoff | Shared database / File | Bulk data transfer | VSAM file share |
| Event-driven trigger | Event Stream | Multiple consumers | JCL job dependency |

### API Gateway Routing Table

| Route Path | Backend Service | Auth Required | Rate Limit |
|-----------|-----------------|--------------|-----------|
| /api/v1/auth/** | auth-service | No | 100 req/min |
| /api/v1/accounts/** | account-service | Yes (USER/ADMIN) | 500 req/min |
| /api/v1/cards/** | card-service | Yes (USER/ADMIN) | 500 req/min |
| /api/v1/transactions/** | transaction-service | Yes (USER/ADMIN) | 200 req/min |
| /api/v1/admin/** | admin-service | Yes (ADMIN only) | 100 req/min |

### Circuit Breaker Configuration

| Service Call | Circuit Breaker | Timeout | Retry | Fallback |
|-------------|----------------|---------|-------|----------|
| transaction → card | @CircuitBreaker | 3s | 2 | Return cached card status |
| transaction → account | @CircuitBreaker | 3s | 2 | Reject transaction (safe) |
| auth → admin | @CircuitBreaker | 2s | 1 | Return minimal user info |

## Integration Patterns

| Pattern | From | To | Protocol | COBOL Source |
|---------|------|-----|---------|-------------|
| [pattern] | [from] | [to] | [protocol] | [program.cbl] |

## System Context Diagram

```mermaid
C4Context
    title System Context diagram
    Person(customer, "Customer")
    System(system, "Application", "Core banking application")
    System_Ext(mainframe, "Mainframe", "Legacy CICS system")
    Rel(customer, system, "Uses")
    Rel(system, mainframe, "Syncs data with")
```

## Data Flow Summary

| Flow | Source Program | Data | Destination | Via |
|------|---------------|------|------------|-----|
| [name] | [pgm] | [data] | [dest] | [trans] |

## Microservice Decomposition

### Module Dependency Graph (Mermaid)

Required output: Generate a module dependency graph showing ALL inter-module relationships with clear directional edges.

### Rule: Use Forward Engineering

Build the target architecture by asking:
1. **What business capability does this module provide?** → Defines service boundary
2. **What data does it own?** → Defines Entity + Repository
3. **What triggers it?** → Defines API/Event endpoints
4. **What does it depend on?** → Defines integration patterns
5. **How does it communicate with other services?** → Defines protocol (REST/MQ/Event)

## JCL Conversion to Spring Batch

### Summary Table

| JCL Job | Category | Spring Batch Job | Complexity |
|---------|----------|-----------------|-----------|
| [name] | [category] | [BatchConfig] | High/Med/Low |

### JCL DD → ItemReader/ItemWriter

| JCL DD Statement | Dataset | Reader/Writer | Configuration |
|-----------------|---------|--------------|---------------|
| DD DSN=input | [name] | FlatFileItemReader | lines to skip, delimiter |

### COND → Skip/Retry

| JCL Step | COND | Spring Batch Policy |
|-----------|------|-------------------|
| STEP1 | (0,NE) | .next() unconditional |
| STEP2 | (4,LT) | .on("FAILED").to(skipStep) |

### Scheduler Mapping (if scheduler exists)

| # | Scheduler | CA-7/Control-M | Target |
|---|-----------|---------------|--------|
| 1 | [name] | [job] | @Scheduled cron="..." |

## Security Architecture (RACF → Spring Security)

### User/Role Configuration

| Component | Source | Target Spring Security |
|-----------|--------|----------------------|
| Authentication | RACF User ID | JWT + BCrypt |
| Authorization | RACF Profiles | @PreAuthorize("hasRole") |
| Transaction Auth | Resource Class | Method-level @PreAuthorize |

### Inter-Service Authentication

| Pattern | Implementation | Notes |
|---------|---------------|-------|
| Internal REST calls | mTLS / Service Account JWT | Gateway handles external auth |
| Async messages | Message signing / TLS | Queue-level auth |
| Shared database | Same DB user, schema-level ACL | Services share DB, not schemas |

## Execution Steps

### Step 1: Build Dependency Graph

From Phase 1 findings and Phase 5 analysis:
1. Build a complete program-to-program dependency matrix
2. Identify direct CALL/LINK relationships
3. Identify data dependencies (VSAM file sharing)
4. Map to target service boundaries

### Step 2: Draw Current-State Architecture

Generate Mermaid diagram showing:
- All programs as nodes
- All data files as nodes
- All external system integrations
- Directional arrows for dependencies
- Color code: CICS=blue, Batch=green, External=red

### Step 3: Design Target Architecture

Apply forward engineering principles:
1. Group programs by business domain
2. Define service boundaries (single domain ownership)
3. Define integration patterns between services
4. Add infrastructure layer (Gateway, MQ, Cache)
5. **Define inter-service communication protocol for every dependency**

### Step 4: Map JCL to Spring Batch

For each JCL file:
1. Map DD statements to FlatFileItemReader/Writer or JpaItemReader/Writer
2. Translate COND parameters to Batch skip/retry policies
3. Map GDG references to partitioned processing

### Step 5: Map Security

For RACF profiles found:
1. Map User authentication → JWT
2. Map Resource authorization → @PreAuthorize
3. Document the migration of plain-text passwords → BCrypt
4. Define inter-service authentication strategy

### Step 6: Export Architecture Diagrams

Write `06-architecture/architecture-diagrams.md`
Write `06-architecture/scheduler-mapping.md` (if scheduler exists)

## Quality Gate (Human Review CP-3)

- [ ] Every diagram component traceable to COBOL source
- [ ] All Mermaid diagrams verified rendering correctly
- [ ] Service boundaries follow single-ownership principle
- [ ] **Inter-service protocol defined for every service dependency**
- [ ] **API Gateway routing table covers all services**
- [ ] **Circuit breaker configuration defined for all synchronous calls**
- [ ] Solution architect invited to review CP-3
- [ ] Save `_state-snapshot.json` with {'phase':6,'status':'pending-review'}
