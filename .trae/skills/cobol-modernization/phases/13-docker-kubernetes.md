# Phase 13: Docker & Kubernetes Deployment

## Objective

Containerize the migrated Java Spring Boot application and define Kubernetes deployment manifests with health probes, resource limits, auto-scaling, secret management, and service exposition. The deployment must achieve parity with the reliability characteristics of the original CICS/Mainframe environment.

## Input

- Phase 6: Architecture Blueprint — target deployment topology
- Phase 8: Deliverable Specifications (application.yml, actuator endpoints)
- Phase 9: Generated Code (final JAR artifact)
- Phase 12: CI/CD Pipeline (Docker build stage)

## Deliverables

- `13-docker-kubernetes/Dockerfile` — Optimized multi-stage Docker build
- `13-docker-kubernetes/deployment.yaml` — Kubernetes Deployment manifest
- `13-docker-kubernetes/service.yaml` — Kubernetes Service manifest
- `13-docker-kubernetes/configmap.yaml` — Application configuration
- `13-docker-kubernetes/secrets.yaml` — Secret references template
- `13-docker-kubernetes/hpa.yaml` — Horizontal Pod Autoscaler
- `13-docker-kubernetes/ingress.yaml` — Ingress / API Gateway routing
- `13-docker-kubernetes/docker-compose.yml` — Local development stack

## Dockerfile

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

## Kubernetes Deployment

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

## Production Operations Configuration

### Prometheus Metrics

```yaml
# application.yml additions for production
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

### Resilience Patterns

```java
// Circuit Breaker (Resilience4j)
@CircuitBreaker(name = "accountService", fallbackMethod = "accountFallback")
@Retry(name = "accountService", maxAttempts = 3)
public Account getAccount(String accountId) { ... }

// Rate Limiting (Bucket4j)
@RateLimiter(name = "standardApi")
public Response processRequest(Request request) { ... }
```

```yaml
# Resilience4j configuration
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

### Distributed Tracing

```yaml
# Micrometer Tracing + Zipkin
management:
  tracing:
    sampling:
      probability: 0.1
  zipkin:
    tracing:
      endpoint: http://zipkin:9411/api/v2/spans
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

### Step 1: Write Dockerfile

Create the `Dockerfile` using the multi-stage build pattern above. Verify:
- Non-root user (`appuser:appgroup`)
- Health check via Actuator
- ZGC for low-pause GC (critical for transactional systems)
- Explicit JVM heap settings

### Step 2: Write Kubernetes Deployment Manifest

Generate `deployment.yaml` with:
- 3 replicas minimum for high availability
- Resource requests and limits (adjust based on load testing from Phase 20)
- Liveness and readiness probes on Actuator endpoints
- Secret references for DB passwords and API keys (never hardcoded)

### Step 3: Write Kubernetes Service Manifest

Generate `service.yaml`:
- `ClusterIP` for internal service-to-service communication
- Port 80 → container port 8080
- If external access needed, add `LoadBalancer` type or Ingress

### Step 4: Create ConfigMap and Secrets Templates

Generate `configmap.yaml` for non-sensitive application configuration.
Generate `secrets.yaml` template documenting which secrets need to be created (actual values via `kubectl create secret` or external secrets manager).

### Step 5: Configure HPA (Horizontal Pod Autoscaler)

Generate `hpa.yaml`:
- Target CPU utilization: 70%
- Min replicas: 3, Max replicas: 10
- Scale based on custom metrics if needed (e.g., request latency)

### Step 6: Create Docker Compose for Local Dev

Generate `docker-compose.yml`:
- `postgres:15-alpine` (database)
- `redis:7-alpine` (cache)
- `app:latest` (Spring Boot application)
- Health checks and dependency ordering (`depends_on` with conditions)

### Step 7: Configure Monitoring Dashboards

Generate Grafana dashboard JSON templates:
- JVM metrics (heap, GC, threads)
- Business metrics (transaction rate, error rate)
- Infrastructure metrics (CPU, memory, network)

## Quality Gate

- [ ] Dockerfile with health checks and non-root user
- [ ] K8s Deployment with liveness + readiness probes
- [ ] K8s Service with ClusterIP (no unnecessary external exposure)
- [ ] Resource requests AND limits defined (not just requests)
- [ ] Secrets referenced via `secretKeyRef` (not env vars with plaintext)
- [ ] HPA configured with CPU and/or custom metrics
- [ ] Graceful shutdown timeout ≥ 30s (CICS transaction completion equivalent)
- [ ] Circuit breaker configured for all external service calls
- [ ] Distributed tracing sampling rate tuned (0.1 for prod, 1.0 for dev)
- [ ] Prometheus metrics endpoint enabled and scraped by monitoring stack
- [ ] `_state-snapshot.json` updated to `{'phase':13,'status':'complete'}`
