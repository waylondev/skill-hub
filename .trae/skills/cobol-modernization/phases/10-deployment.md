# Phases 10-20: Deployment, Compliance & Production Operations

## Phase 10: Frontend Migration Guide (BMS → React/Angular)

Generate `10-frontend-migration/` directory with:
- Screen layout references from BMS ASCII layouts
- Component mapping (BMS field → React/Angular component)
- API integration code (fetch/axios to REST endpoints)
- Navigation routing (React Router / Angular Router from state machine)

## Phase 11: Cost Estimation & Planning

### Infrastructure Cost (Monthly)

| Component | Service | Spec | Monthly Cost |
|-----------|---------|------|-------------|
| Compute | [provider] | [spec] | [$] |
| Database | [provider] | [spec] | [$] |
| Cache | [provider] | [spec] | [$] |
| Network | [provider] | [spec] | [$] |
| Monitoring | [provider] | [spec] | [$] |
| **Total Monthly** | | | **[sum]** |

### Migration Effort Estimation

| Phase | Resource Type | Effort (hours) | Duration (weeks) |
|-------|--------------|----------------|-----------------|
| COBOL Program Analysis | Senior COBOL Developer | [N] | [N] |
| Entity/Repository Design | Java Architect | [N] | [N] |
| Service Implementation | Java Developer | [N] | [N] |
| Database Migration | DBA | [N] | [N] |
| Testing | QA Engineer | [N] | [N] |
| Deployment / DevOps | DevOps Engineer | [N] | [N] |
| **Total** | | **[sum]h** | **[sum] weeks** |

## Phase 12: CI/CD Pipeline

### Jenkinsfile (Declarative Pipeline)
```groovy
pipeline {
    agent any
    stages {
        stage('Checkout') { steps { checkout scm } }
        stage('Build') { steps { sh 'mvn clean compile' } }
        stage('Test') { steps { sh 'mvn test' } }
        stage('Verify') { steps { sh 'mvn verify -Pintegration' } }
        stage('SonarQube') { steps { sh 'mvn sonar:sonar' } }
        stage('Package') { steps { sh 'mvn package -DskipTests' } }
        stage('Docker Build & Push') { /* docker build + push */ }
        stage('Deploy to Dev') { /* kubectl/k8s deploy */ }
        stage('Integration Tests') { /* run integration suite */ }
        stage('Deploy to Staging') { /* with approval */ }
        stage('Performance Tests') { /* JMeter/Gatling */ }
    }
}
```

### GitHub Actions
```yaml
name: CI/CD Pipeline
on: [push, pull_request]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Set up JDK 21
        uses: actions/setup-java@v4
        with:
          java-version: '21'
          distribution: 'temurin'
      - name: Build & Test
        run: mvn clean verify
      - name: SonarQube
        run: mvn sonar:sonar -Dsonar.host.url=${{ secrets.SONAR_URL }} -Dsonar.token=${{ secrets.SONAR_TOKEN }}
      - name: Build Docker Image
        run: docker build -t ${{ secrets.REGISTRY }}/app:${{ github.sha }} .
      - name: Push Docker Image
        run: docker push ${{ secrets.REGISTRY }}/app:${{ github.sha }}
```

## Phase 13: Docker & Kubernetes Deployment

### Dockerfile
```dockerfile
FROM eclipse-temurin:21-jre-alpine AS runtime
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser
COPY target/*.jar app.jar
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD wget -qO- http://localhost:8080/actuator/health || exit 1
ENTRYPOINT ["java", "-XX:+UseZGC", "-Xms512m", "-Xmx1024m", "-jar", "/app.jar"]
```

### Kubernetes Deployment
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-deployment
  labels:
    app: cobol-migration
spec:
  replicas: 3
  selector:
    matchLabels:
      app: cobol-migration
  template:
    metadata:
      labels:
        app: cobol-migration
    spec:
      containers:
      - name: app
        image: registry.example.com/app:latest
        ports:
        - containerPort: 8080
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "1024Mi"
            cpu: "1000m"
        livenessProbe:
          httpGet:
            path: /actuator/health/liveness
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /actuator/health/readiness
            port: 8080
          initialDelaySeconds: 15
          periodSeconds: 5
        env:
        - name: SPRING_PROFILES_ACTIVE
          value: "production"
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: app-secrets
              key: db-password
---
apiVersion: v1
kind: Service
metadata:
  name: app-service
spec:
  selector:
    app: cobol-migration
  ports:
  - port: 80
    targetPort: 8080
  type: ClusterIP
```

## Phase 14: Quick Start (Developer Onboarding)

Generate `14-quick-start/` directory with:
- Developer onboarding guide
- Local development setup (docker-compose)
- API documentation with SpringDoc OpenAPI
- Sample requests and responses (curl, Postman collection)

```bash
# Quick Start Commands
docker-compose up -d                    # Start PostgreSQL + Redis + App
./mvnw spring-boot:run                  # Start application
open http://localhost:8080/swagger-ui   # API documentation
open http://localhost:8080/actuator     # Actuator endpoints
```

## Phase 15: COBOL Dialect Support (Extended)

- IBM Enterprise COBOL → Standard mapping (most common)
- Micro Focus COBOL → Standard mapping
- Hitachi COBOL → Standard mapping
- Fujitsu COBOL → Standard mapping
- ACUCOBOL → Standard mapping
- GnuCOBOL → Standard mapping

## Phase 16: Toolchain & Migration Utilities

- Flyway version tracking SQL template
- VSAM→PostgreSQL DDL generator
- COMP-3 hex dump → BigDecimal converter
- EBCDIC→UTF-8 file converter
- JCL dependency parser
- COPYBOOK cross-reference generator

## Phase 17: Production Compliance

### Security Compliance Templates
- PCI-DSS 4.0 requirements → Spring Security config
- HIPAA/HITECH requirements → Spring Security config
- SOX requirements → Audit log config
- GDPR/CCPA requirements → PII handling config
- FedRAMP requirements → Kubernetes hardening config

### Performance Benchmarking (Phase 20)
```java
// JMH Benchmark: Core business logic
@BenchmarkMode(Mode.Throughput)
@OutputTimeUnit(TimeUnit.SECONDS)
@State(Scope.Benchmark)
public class PaymentServiceBenchmark {
    @Benchmark
    public void processPayment() {
        service.processPayment("12345678901", true);
    }
}
```

### Production Operations
- Prometheus metrics endpoints
- Grafana dashboard JSON templates
- Distributed tracing (Micrometer Tracing + Zipkin)
- Circuit breaker (Resilience4j)
- Rate limiting (Bucket4j)
- Graceful shutdown (30s timeout)

## Execution Notes

Phases 10-20 are executed only in `mode=full`. For `mode=lite`, skip to the Generation phase (Phase 9 then stop).

When executing full mode, always process phases sequentially as they depend on previous outputs.

## Quality Gate

- [ ] Dockerfile with health checks
- [ ] K8s manifests with probes
- [ ] CI/CD pipeline defined (Jenkins or GitHub Actions)
- [ ] Monitoring dashboards configured
- [ ] Security compliance templates provided
- [ ] Performance benchmarks defined
- [ ] `_state-snapshot.json` updated to {'phase':'complete','status':'done'}
- [ ] Run ALL Mandatory QA Checks 1-30 from [references/quality-checklist.md](../references/quality-checklist.md)
