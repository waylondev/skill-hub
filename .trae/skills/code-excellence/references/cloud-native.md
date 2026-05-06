# Cloud-Native Kubernetes & Container Best Practices — Architect-Level Reference

## Purpose

This reference encodes production-grade patterns for deploying, operating, and securing
containerized workloads on Kubernetes. It assumes you already know what a Pod is — this
document tells you how to run it correctly at scale, with zero ambiguity.

Apply `code-excellence` SKILL.md first, then `springboot.md` / `java.md`, then this reference
for infrastructure-facing decisions.

---

## 1. Kubernetes Deployment / Service / Ingress Templates

### Deployment — Baseline Production Template

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: order-service
  labels:
    app: order-service
    version: v1.2.3
    tier: backend
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 25%
      maxUnavailable: 0          # Never drop below desired capacity during rollout
  selector:
    matchLabels:
      app: order-service
  template:
    metadata:
      labels:
        app: order-service
        version: v1.2.3
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
        prometheus.io/path: "/actuator/prometheus"
    spec:
      serviceAccountName: order-service-sa
      securityContext:
        runAsNonRoot: true
        runAsUser: 65534
        fsGroup: 65534
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: app
          image: registry.example.com/order-service:v1.2.3
          imagePullPolicy: IfNotPresent
          ports:
            - name: http
              containerPort: 8080
              protocol: TCP
            - name: management
              containerPort: 8081
              protocol: TCP
          env:
            - name: SPRING_PROFILES_ACTIVE
              value: "production"
            - name: JAVA_OPTS
              value: "-XX:+UseG1GC -XX:MaxRAMPercentage=75.0 -XX:InitialRAMPercentage=50.0"
          envFrom:
            - configMapRef:
                name: order-service-config
                optional: false
          volumeMounts:
            - name: tmp
              mountPath: /tmp
            - name: secrets
              mountPath: /etc/secrets
              readOnly: true
          resources:
            requests:
              memory: "512Mi"
              cpu: "250m"
            limits:
              memory: "1Gi"
              cpu: "1000m"
          livenessProbe:
            httpGet:
              path: /actuator/health/liveness
              port: management
            initialDelaySeconds: 60
            periodSeconds: 10
            timeoutSeconds: 5
            failureThreshold: 3
          readinessProbe:
            httpGet:
              path: /actuator/health/readiness
              port: management
            initialDelaySeconds: 10
            periodSeconds: 5
            timeoutSeconds: 3
            failureThreshold: 3
          startupProbe:
            httpGet:
              path: /actuator/health/liveness
              port: management
            initialDelaySeconds: 10
            periodSeconds: 5
            timeoutSeconds: 3
            failureThreshold: 30          # 30 * 5s = 150s max startup time
          lifecycle:
            preStop:
              exec:
                command: ["/bin/sh", "-c", "sleep 15"]
      volumes:
        - name: tmp
          emptyDir: {}
        - name: secrets
          csi:
            driver: secrets-store.csi.k8s.io
            readOnly: true
            volumeAttributes:
              secretProviderClass: order-service-aws-secrets
      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: topology.kubernetes.io/zone
          whenUnsatisfiable: DoNotSchedule
          labelSelector:
            matchLabels:
              app: order-service
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                labelSelector:
                  matchExpressions:
                    - key: app
                      operator: In
                      values:
                        - order-service
                topologyKey: kubernetes.io/hostname
```

### Service — Headless for Stateful, ClusterIP for Stateless

```yaml
apiVersion: v1
kind: Service
metadata:
  name: order-service
  labels:
    app: order-service
spec:
  type: ClusterIP
  selector:
    app: order-service
  ports:
    - name: http
      port: 80
      targetPort: http
      protocol: TCP
    - name: management
      port: 8081
      targetPort: management
      protocol: TCP
```

### Ingress — TLS-Terminated with Rate Limiting

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: order-service-ingress
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/proxy-body-size: "10m"
    nginx.ingress.kubernetes.io/rate-limit: "100"
    nginx.ingress.kubernetes.io/rate-limit-window: "1m"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - api.example.com
      secretName: api-example-com-tls
  rules:
    - host: api.example.com
      http:
        paths:
          - path: /orders
            pathType: Prefix
            backend:
              service:
                name: order-service
                port:
                  number: 80
```

**Rules**:
- Always separate `management` port from `http` port. Never expose actuator on the same port as business traffic.
- `maxUnavailable: 0` ensures capacity is never lost during deployment. Accept the slower rollout.
- Use `topologySpreadConstraints` + `podAntiAffinity` together for zone-aware HA.

---

## 2. Health Probe Specifications

### Probe Decision Matrix

| Probe | Purpose | Failure Action | Endpoint |
|-------|---------|----------------|----------|
| **Startup** | "Has the app finished starting?" | Kill & restart container | `/actuator/health/liveness` |
| **Liveness** | "Is the app still alive?" | Kill & restart container | `/actuator/health/liveness` |
| **Readiness** | "Is the app ready to receive traffic?" | Remove from Service endpoints | `/actuator/health/readiness` |

### Spring Boot Actuator Configuration

```yaml
management:
  server:
    port: 8081
  endpoints:
    web:
      exposure:
        include: health, prometheus, info
      base-path: /actuator
  endpoint:
    health:
      probes:
        enabled: true
      show-details: never
      group:
        readiness:
          include: readinessState, db, kafka
        liveness:
          include: livenessState
```

### Custom Readiness Indicator (Java)

```java
@Component
public class KafkaReadinessIndicator implements HealthIndicator {
    private final KafkaAdmin admin;

    public KafkaReadinessIndicator(KafkaAdmin admin) {
        this.admin = admin;
    }

    @Override
    public Health health() {
        try (var client = AdminClient.create(admin.getConfigurationProperties())) {
            client.listTopics().names().get(5, TimeUnit.SECONDS);
            return Health.up().build();
        } catch (Exception e) {
            return Health.down()
                .withDetail("error", "Cannot reach Kafka")
                .withException(e)
                .build();
        }
    }
}
```

**Critical rules**:
- Liveness MUST NOT depend on external systems (DB, Kafka, downstream APIs). A transient dependency failure must NOT trigger container restart loops.
- Readiness SHOULD depend on all external dependencies required to serve traffic.
- Startup probe disables liveness/readiness until it succeeds. Use it for slow-starting JVM apps to prevent premature kill cycles.

---

## 3. Sidecar Patterns

### Log Shipping (Fluent Bit Sidecar)

```yaml
containers:
  - name: app
    volumeMounts:
      - name: logs
        mountPath: /app/logs
  - name: fluent-bit
    image: fluent/fluent-bit:2.2
    volumeMounts:
      - name: logs
        mountPath: /app/logs
        readOnly: true
      - name: fluent-bit-config
        mountPath: /fluent-bit/etc
    resources:
      requests:
        memory: "64Mi"
        cpu: "50m"
      limits:
        memory: "128Mi"
        cpu: "100m"
volumes:
  - name: logs
    emptyDir: {}
  - name: fluent-bit-config
    configMap:
      name: fluent-bit-config
```

### Config Reload (Without Restart)

```yaml
containers:
  - name: app
    volumeMounts:
      - name: config
        mountPath: /app/config
  - name: config-reloader
    image: ghcr.io/stakater/reloader:v1.0
    env:
      - name: CONFIG_DIR
        value: /app/config
      - name: PROCESS_NAME
        value: "java"
```

**Sidecar rules**:
- Sidecars share `emptyDir` volumes for file-based communication. Never use the main container's filesystem directly.
- Resource limits on sidecars must be capped aggressively. A log shipper should never consume more than 10% of the Pod's CPU.
- If the sidecar fails, the entire Pod is not Ready. Design sidecars to be crash-loop resilient or use `restartPolicy: Always` with health checks.

---

## 4. ConfigMap / Secret Management Strategies

### Strategy Matrix

| Approach | Use For | Avoid For | Rationale |
|----------|---------|-----------|-----------|
| **Env vars from ConfigMap** | Non-sensitive app config, feature flags | Secrets | Visible in `ps e`, process listings, crash dumps |
| **Mounted volumes from ConfigMap** | Large config files, JSON/YAML configs | — | File changes trigger inotify; app can hot-reload |
| **Env vars from Secrets** | Only if absolutely necessary | Production secrets | Same leakage risk; use only for bootstrap tokens |
| **Mounted volumes from Secrets** | TLS certs, DB passwords, API keys | — | Files are tmpfs (RAM-only), never hit node disk |
| **External secret operator** | Cloud KMS, Vault, AWS Secrets Manager | — | Secrets never stored in etcd; rotated automatically |

### ConfigMap Template

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: order-service-config
data:
  application.yml: |
    server:
      port: 8080
    spring:
      kafka:
        bootstrap-servers: kafka:9092
  LOG_LEVEL: "INFO"
  FEATURE_FLAG_NEW_CHECKOUT: "true"
```

### Secret with CSI Driver (AWS Secrets Manager)

```yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: order-service-aws-secrets
spec:
  provider: aws
  parameters:
    objects: |
      - objectName: "prod/order-service/db-password"
        objectType: "secretsmanager"
        jmesPath:
          - path: "password"
            objectAlias: "db-password"
  secretObjects:
    - secretName: order-service-db-secret
      type: Opaque
      data:
        - objectName: db-password
          key: password
```

### Spring Boot Profile-Specific ConfigMap Mount

```yaml
# Mount per-profile config as application-{profile}.yml
volumeMounts:
  - name: config
    mountPath: /app/config/application-production.yml
    subPath: application-production.yml
volumes:
  - name: config
    configMap:
      name: order-service-config-prod
```

**Rules**:
- Never commit raw Secret YAML to Git. Use Sealed Secrets, SOPS, or external secret operators.
- ConfigMap changes do NOT restart Pods. Use Reloader (Stakater) or Argo CD sync waves to trigger rolling updates.
- For Java apps, prefer `spring.config.additional-location` pointing to mounted volumes over env var injection.

---

## 5. Resource Limits and HPA Strategies

### Resource Specification Rules

| Resource | Request | Limit | Ratio Limit:Request |
|----------|---------|-------|---------------------|
| CPU | Based on p95 steady-state usage | 2-4x request | ≤ 4x |
| Memory | Based on heap + metaspace + native + 20% headroom | = request | 1:1 |

**Memory limit MUST equal request** for Java workloads. Kubernetes OOMKills based on limit, not request. If limit > request, the JVM sees more RAM than guaranteed and can be killed mid-GC.

```yaml
resources:
  requests:
    memory: "1Gi"
    cpu: "500m"
  limits:
    memory: "1Gi"          # Equal to request
    cpu: "1000m"           # 2x request
```

### HorizontalPodAutoscaler

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: order-service-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: order-service
  minReplicas: 3
  maxReplicas: 20
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 80
    - type: Pods
      pods:
        metric:
          name: http_server_requests_seconds_count
        target:
          type: AverageValue
          averageValue: "1000"
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
        - type: Percent
          value: 100
          periodSeconds: 60
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
        - type: Percent
          value: 10
          periodSeconds: 60
```

**HPA rules**:
- Always set `minReplicas >= 2` for HA. Single-replica HPA is an oxymoron.
- `scaleDown.stabilizationWindowSeconds` should be 5x the scale-up window to prevent flapping.
- Use custom metrics (Prometheus adapter) for scaling on business signals (queue depth, latency) rather than just CPU.
- For JVM apps, scale-up based on CPU is reliable; scale-down based on memory to prevent OOM during traffic drops.

---

## 6. Service Mesh Patterns

### mTLS (Strict Mode)

```yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: production
spec:
  mtls:
    mode: STRICT
```

### Traffic Splitting (Canary)

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: order-service
spec:
  hosts:
    - order-service
  http:
    - match:
        - headers:
            x-canary:
              exact: "true"
      route:
        - destination:
            host: order-service
            subset: v2
          weight: 100
    - route:
        - destination:
            host: order-service
            subset: v1
          weight: 90
        - destination:
            host: order-service
            subset: v2
          weight: 10
```

### Circuit Breaking at Mesh Level

```yaml
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: payment-service-cb
spec:
  host: payment-service
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 100
      http:
        http1MaxPendingRequests: 50
        maxRequestsPerConnection: 10
    outlierDetection:
      consecutive5xxErrors: 5
      interval: 30s
      baseEjectionTime: 30s
      maxEjectionPercent: 50
```

**Mesh rules**:
- Application-level circuit breakers (Resilience4j) and mesh-level circuit breakers are NOT redundant. App-level protects the caller; mesh-level protects the infrastructure.
- mTLS strict mode breaks legacy clients. Use `PERMISSIVE` during migration, then enforce `STRICT` with a deadline.
- Traffic splitting by header (`x-canary`) is safer than weight-based for internal testing. Weight-based is for production rollouts.

---

## 7. Observability in Container Environments

### Prometheus Scraping (Annotations)

```yaml
metadata:
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "8080"
    prometheus.io/path: "/actuator/prometheus"
```

### Spring Boot Micrometer Configuration

```yaml
management:
  metrics:
    export:
      prometheus:
        enabled: true
    tags:
      application: ${spring.application.name}
      environment: ${SPRING_PROFILES_ACTIVE:unknown}
    distribution:
      percentiles-histogram:
        http.server.requests: true
      slo:
        http.server.requests: 50ms,100ms,200ms,500ms,1s,5s
  endpoint:
    prometheus:
      enabled: true
```

### Custom Business Metric (Java)

```java
@Component
public class OrderMetrics {
    private final Counter orderCounter;
    private final Timer orderProcessingTimer;

    public OrderMetrics(MeterRegistry registry) {
        this.orderCounter = Counter.builder("orders.placed")
            .description("Total orders placed")
            .tag("currency", "USD")
            .register(registry);
        this.orderProcessingTimer = Timer.builder("orders.processing.time")
            .description("Order processing duration")
            .publishPercentiles(0.5, 0.95, 0.99)
            .register(registry);
    }

    public void recordOrderPlaced() {
        orderCounter.increment();
    }

    public void recordProcessingTime(Duration d) {
        orderProcessingTimer.record(d);
    }
}
```

### Fluent Bit → Loki / CloudWatch

```yaml
# Fluent Bit ConfigMap snippet
filters: |
  [FILTER]
      Name kubernetes
      Match kube.*
      Merge_Log On
      Keep_Log Off
      K8S-Logging.Parser On
      K8S-Logging.Exclude On

  [FILTER]
      Name grep
      Match kube.*
      Exclude log /health

output: |
  [OUTPUT]
      Name loki
      Match kube.*
      Host loki.monitoring.svc.cluster.local
      Labels job=fluentbit, namespace=$kubernetes['namespace_name'], pod=$kubernetes['pod_name']
```

### Jaeger Sidecar (OpenTelemetry Agent)

```yaml
containers:
  - name: app
    env:
      - name: OTEL_EXPORTER_OTLP_ENDPOINT
        value: "http://localhost:4317"
      - name: OTEL_SERVICE_NAME
        value: "order-service"
      - name: OTEL_TRACES_SAMPLER
        value: "parentbased_traceidratio"
      - name: OTEL_TRACES_SAMPLER_ARG
        value: "0.1"
  - name: otel-agent
    image: otel/opentelemetry-collector-contrib:0.91.0
    args: ["--config=/conf/agent.yaml"]
    volumeMounts:
      - name: otel-config
        mountPath: /conf
    resources:
      requests:
        memory: "64Mi"
        cpu: "50m"
```

**Observability rules**:
- Every service must expose `/actuator/prometheus` with `application` and `environment` tags.
- Log aggregation must parse JSON logs (structured logging). Never grep plain text in production.
- Sampling rate for tracing: 100% for errors, 10% for success paths in high-traffic services.
- Health check endpoints (`/health`) must be excluded from access logs to prevent log noise.

---

## 8. Graceful Shutdown and Pod Lifecycle Management

### Spring Boot Graceful Shutdown

```yaml
server:
  shutdown: graceful
spring:
  lifecycle:
    timeout-per-shutdown-phase: 30s
  kafka:
    listener:
      immediate-stop: false
```

### PreStop Hook + Termination Grace Period

```yaml
spec:
  terminationGracePeriodSeconds: 60
  containers:
    - name: app
      lifecycle:
        preStop:
          exec:
            command: ["/bin/sh", "-c", "sleep 15"]
```

### Java Shutdown Hook for Resource Cleanup

```java
@Component
public class GracefulShutdownHandler implements ApplicationListener<ContextClosedEvent> {
    private final KafkaTemplate<String, String> kafkaTemplate;
    private final ExecutorService executor;

    public GracefulShutdownHandler(KafkaTemplate<String, String> kafkaTemplate) {
        this.kafkaTemplate = kafkaTemplate;
        this.executor = Executors.newFixedThreadPool(4);
    }

    @Override
    public void onApplicationEvent(ContextClosedEvent event) {
        // 1. Stop accepting new requests (Spring does this automatically)
        // 2. Flush in-flight Kafka messages
        kafkaTemplate.flush();
        // 3. Wait for executor tasks to complete
        executor.shutdown();
        try {
            if (!executor.awaitTermination(20, TimeUnit.SECONDS)) {
                executor.shutdownNow();
            }
        } catch (InterruptedException e) {
            executor.shutdownNow();
            Thread.currentThread().interrupt();
        }
    }
}
```

### Pod Lifecycle Sequence

```
1. kubectl delete pod / SIGTERM received
2. Endpoint controller removes Pod from Service endpoints (async, ~1-2s)
3. preStop hook executes (sleep 15s — allows step 2 to complete)
4. Container receives SIGTERM
5. Spring Boot stops accepting new connections
6. In-flight requests complete (up to timeout-per-shutdown-phase)
7. ContextClosedEvent fires — cleanup resources
8. If still running after terminationGracePeriodSeconds → SIGKILL
```

**Rules**:
- `preStop.sleep` is mandatory for Java apps. Without it, the container may receive traffic after SIGTERM due to endpoint propagation delay.
- `terminationGracePeriodSeconds` must be > `timeout-per-shutdown-phase` + `preStop` duration.
- Never call `System.exit()` in shutdown hooks. Let the JVM exit naturally after Spring context closes.

---

## 9. Security Hardening

### Pod Security Standards (Restricted)

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: latest
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

### Security Context in Deployment

```yaml
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 65534
    fsGroup: 65534
    seccompProfile:
      type: RuntimeDefault
  containers:
    - name: app
      securityContext:
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        capabilities:
          drop:
            - ALL
```

### NetworkPolicy — Default Deny + Explicit Allow

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: production
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: order-service-allow
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: order-service
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              name: ingress-nginx
        - podSelector:
            matchLabels:
              app: api-gateway
      ports:
        - protocol: TCP
          port: 8080
  egress:
    - to:
        - podSelector:
            matchLabels:
              app: postgres
      ports:
        - protocol: TCP
          port: 5432
    - to:
        - podSelector:
            matchLabels:
              app: kafka
      ports:
        - protocol: TCP
          port: 9092
    - to: []  # DNS
      ports:
        - protocol: UDP
          port: 53
```

### RBAC — Least Privilege ServiceAccount

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: order-service-sa
  namespace: production
automountServiceAccountToken: false    # Disable if not needed
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: order-service-role
  namespace: production
rules:
  - apiGroups: [""]
    resources: ["configmaps"]
    verbs: ["get", "list"]
    resourceNames: ["order-service-config"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: order-service-rb
  namespace: production
subjects:
  - kind: ServiceAccount
    name: order-service-sa
    namespace: production
roleRef:
  kind: Role
  name: order-service-role
  apiGroup: rbac.authorization.k8s.io
```

**Security rules**:
- `readOnlyRootFilesystem: true` requires `emptyDir` mounts for `/tmp` and any writable paths.
- `automountServiceAccountToken: false` prevents Pod → API server access unless explicitly needed.
- NetworkPolicy default-deny is the only sane default. Every allowed flow must be explicitly documented.
- Never use `cluster-admin` for application ServiceAccounts. Use Role + RoleBinding scoped to namespace.

---

## 10. Multi-Environment Config Management

### Directory Structure (Kustomize)

```
base/
  deployment.yaml
  service.yaml
  kustomization.yaml
overlays/
  dev/
    configmap.yaml
    hpa.yaml
    kustomization.yaml
  staging/
    configmap.yaml
    hpa.yaml
    kustomization.yaml
  prod/
    configmap.yaml
    hpa.yaml
    networkpolicy.yaml
    kustomization.yaml
```

### Base Kustomization

```yaml
# base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - deployment.yaml
  - service.yaml
commonLabels:
  app: order-service
images:
  - name: order-service
    newTag: v1.2.3
```

### Production Overlay

```yaml
# overlays/prod/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: production
resources:
  - ../../base
  - networkpolicy.yaml
namePrefix: prod-
replicas:
  - name: order-service
    count: 5
configMapGenerator:
  - name: order-service-config
    behavior: merge
    literals:
      - LOG_LEVEL=WARN
      - FEATURE_FLAG_NEW_CHECKOUT=false
patches:
  - target:
      kind: Deployment
      name: order-service
    patch: |
      - op: replace
        path: /spec/template/spec/containers/0/resources/limits/memory
        value: "2Gi"
```

### Spring Boot Profile Activation

```yaml
# application.yml (base)
spring:
  profiles:
    active: ${SPRING_PROFILES_ACTIVE:local}
  config:
    import: optional:file:/app/config/application-${spring.profiles.active}.yml
```

```yaml
# ConfigMap for prod — mounted as application-production.yml
server:
  shutdown: graceful
spring:
  datasource:
    url: jdbc:postgresql://prod-db.example.com:5432/orders
    hikari:
      maximum-pool-size: 20
management:
  endpoint:
    health:
      show-details: never
```

### Environment-Specific Helm Values

```yaml
# values-prod.yaml
replicaCount: 5
resources:
  limits:
    memory: 2Gi
    cpu: 2000m
  requests:
    memory: 2Gi
    cpu: 1000m
autoscaling:
  enabled: true
  minReplicas: 5
  maxReplicas: 50
  targetCPUUtilizationPercentage: 60
podSecurityContext:
  runAsNonRoot: true
  runAsUser: 65534
networkPolicy:
  enabled: true
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              name: ingress-nginx
```

**Multi-env rules**:
- Use Kustomize for GitOps-native workflows (Argo CD, Flux). Use Helm for templated, consumer-facing charts.
- Never use `latest` tag in production. Tag must be immutable and traceable to a CI build.
- Production overlays MUST include NetworkPolicy, stricter resource limits, and reduced log verbosity.
- Secrets must be environment-specific and never shared between dev/staging/prod.

---

## Quick Checklist

Before deploying to production:

- [ ] Deployment has `securityContext` with `runAsNonRoot`, `readOnlyRootFilesystem`, `drop ALL` capabilities?
- [ ] Liveness probe does NOT depend on external systems (DB, Kafka, downstream APIs)?
- [ ] Readiness probe covers all dependencies required to serve traffic?
- [ ] Startup probe configured for slow-starting JVM apps?
- [ ] `preStop.sleep` hook present to allow endpoint propagation before SIGTERM?
- [ ] `terminationGracePeriodSeconds` > shutdown timeout + preStop duration?
- [ ] Resource `memory.limit` == `memory.request` for Java workloads?
- [ ] HPA `minReplicas >= 2` and scale-down stabilization window >= 5x scale-up?
- [ ] ConfigMap changes trigger rolling update (Reloader / Argo CD sync)?
- [ ] Secrets mounted as volumes (not env vars) and sourced from external KMS/Vault?
- [ ] NetworkPolicy default-deny applied with explicit ingress/egress rules?
- [ ] ServiceAccount has `automountServiceAccountToken: false` unless API access required?
- [ ] RBAC scoped to Role + RoleBinding (not ClusterRole) with minimal verbs?
- [ ] Prometheus scraping annotations present on Pod template?
- [ ] Management port (actuator) separated from business port?
- [ ] Ingress has TLS termination and rate limiting configured?
- [ ] Topology spread constraints enforce zone-aware distribution?
- [ ] Image tag is immutable (SHA or semver), never `latest`?
- [ ] Multi-env config managed via Kustomize overlays or Helm values per environment?
- [ ] Sidecars have resource limits capped at ≤ 10% of Pod total?
