# Resilience Patterns — Architect-Level Reference

## Purpose

Distributed systems fail. Networks partition, services degrade, threads exhaust, and
cascading failures turn a minor blip into a full outage. This reference encodes the
six essential resilience patterns every architect must design into the system before
the first line of business logic is written.

Each pattern answers one question: **"What happens when this call fails?"**

---

## RP-1: Circuit Breaker

**Pattern**: A state machine that detects repeated downstream failures and stops sending
requests to avoid further damage, giving the downstream time to recover. Three states:

- **Closed**: Normal operation. Requests flow through. Failure counter increments.
- **Open**: Failure threshold exceeded. All requests are rejected immediately (fast-fail).
- **Half-Open**: After a configured timeout, a limited number of probe requests are
  allowed through. If they succeed, the breaker closes. If they fail, it re-opens.

**Use when**: Calling any external service that can become degraded — HTTP APIs,
databases, message brokers, third-party SaaS. Every synchronous downstream call
MUST have a circuit breaker.

### ❌ Wrong — Unprotected Downstream Call

```java
@Service
public class PaymentService {
    private final RestClient restClient;

    public PaymentResult charge(PaymentRequest req) {
        return restClient.post()
            .uri("http://payment-gateway/api/charge")
            .body(req)
            .retrieve()
            .body(PaymentResult.class);
        // payment-gateway is slow — every call waits 30s before timing out
        // Threads pile up → thread pool exhausted → entire service hangs
        // Cascading failure: PaymentService down → OrderService down → everything down
    }
}
```

### Root Cause

No mechanism to detect that the downstream is failing. Every thread that calls a degraded
service joins the zombie army — holding resources, blocking callers upstream, eventually
exhausting thread pools and connection pools across the entire call chain.

### ✅ Expert Fix — Resilience4j Circuit Breaker

```java
// Configuration — externalized, not hardcoded
resilience4j.circuitbreaker:
  instances:
    paymentGateway:
      failureRateThreshold: 50       # Open breaker when 50% of calls fail
      slowCallRateThreshold: 80      # Also count slow calls (>5s) as failures
      slowCallDurationThreshold: 5s
      slidingWindowSize: 20          # Evaluate last 20 calls
      slidingWindowType: COUNT_BASED
      waitDurationInOpenState: 15s   # Wait 15s before trying half-open
      permittedNumberOfCallsInHalfOpenState: 3
      minimumNumberOfCalls: 10       # Don't evaluate until at least 10 calls
      automaticTransitionFromOpenToHalfOpenEnabled: true
      recordExceptions:
        - java.net.ConnectException
        - java.net.SocketTimeoutException
        - org.springframework.web.client.HttpServerErrorException
      ignoreExceptions:
        - com.example.InvalidPaymentException  # Don't trip on 4xx business errors
```

```java
@Service
public class PaymentService {
    private final RestClient restClient;
    private final CircuitBreaker circuitBreaker;

    public PaymentService(RestClient restClient,
                          CircuitBreakerRegistry cbRegistry) {
        this.restClient = restClient;
        this.circuitBreaker = cbRegistry.circuitBreaker("paymentGateway");
    }

    public PaymentResult charge(PaymentRequest req) {
        return circuitBreaker.executeSupplier(() -> {
            var response = restClient.post()
                .uri("http://payment-gateway/api/charge")
                .body(req)
                .retrieve()
                .toEntity(PaymentResult.class);

            if (response.getStatusCode().is5xxServerError()) {
                throw new DownstreamFailureException("Gateway returned " + response.getStatusCode());
            }
            return response.getBody();
        });
        // When breaker is OPEN: throws CallNotPermittedException immediately.
        // Caller gets fast-fail in microseconds instead of waiting 30s.
    }
}
```

```java
// CircuitBreaker + Fallback: degrade gracefully instead of propagating error
public PaymentResult chargeWithFallback(PaymentRequest req) {
    return Try.ofSupplier(
        CircuitBreaker.decorateSupplier(circuitBreaker, () -> chargeInternal(req))
    )
    .recover(CallNotPermittedException.class, ex -> {
        log.warn("Payment gateway circuit OPEN — using fallback");
        metrics.circuitOpen.increment();
        return paymentResultFromCache(req); // serve stale data, better than nothing
    })
    .recover(DownstreamFailureException.class, ex -> {
        return PaymentResult.pending(req.orderId()); // async retry later via outbox
    })
    .get();
}
```

**Expert Note**: Circuit breakers detect *failure patterns*, not individual failures. A single
timeout is not enough to open the breaker — the threshold-based evaluation prevents
false positives from transient network blips. Always pair with a fallback strategy:
degraded response, cached data, or queued-async-retry. A breaker without a fallback
just replaces one exception type with another.

---

## RP-2: Bulkhead

**Pattern**: Partition resources so that a failure in one downstream dependency does not
exhaust resources needed by other dependencies. Borrowed from shipbuilding: a
bulkhead prevents a single hull breach from flooding the entire vessel.

**Two isolation strategies**:

- **Thread Pool Isolation**: Each downstream gets a dedicated thread pool with its own
  queue. A slow downstream fills only its own pool — other pools remain available.
- **Semaphore Isolation**: Each downstream call acquires a semaphore permit. Lighter
  weight (no extra threads) but does not protect against slow calls that hold permits.

**Use when**: Your service calls multiple downstream dependencies with different
performance characteristics, failure modes, and criticality levels. Thread pool
isolation is preferred for I/O-bound calls; semaphore isolation for cache lookups.

### ❌ Wrong — Shared Thread Pool

```java
@Configuration
public class HttpClientConfig {
    @Bean
    public RestClient restClient() {
        var pool = new ThreadPoolTaskExecutor();
        pool.setCorePoolSize(20);
        pool.setMaxPoolSize(50);
        pool.setQueueCapacity(200);
        pool.initialize();
        return RestClient.builder()
            .requestFactory(new JdkClientHttpRequestFactory(
                HttpClient.newBuilder().executor(pool.getThreadPoolExecutor()).build()
            ))
            .build();
    }
    // All downstream calls share ONE pool.
    // Payment service is slow → exhausts all 50 threads → inventory service blocked too.
    // One misbehaving dependency takes down the entire application.
}
```

### Root Cause

A shared resource pool means all downstream calls compete for the same threads. A
slow or degraded downstream fills the pool, blocking calls to healthy downstreams that
could otherwise return quickly. The blast radius of a single dependency failure is
the entire application.

### ✅ Expert Fix — Per-Downstream Thread Pools

```java
@Configuration
public class ResilienceConfig {

    @Bean("paymentPool")
    public ThreadPoolTaskExecutor paymentPool() {
        var pool = new ThreadPoolTaskExecutor();
        pool.setCorePoolSize(10);
        pool.setMaxPoolSize(20);
        pool.setQueueCapacity(30);     // Reject when queue full — don't pile up
        pool.setRejectedExecutionHandler(new ThreadPoolExecutor.CallerRunsPolicy());
        pool.setThreadNamePrefix("payment-");
        pool.initialize();
        return pool;
    }

    @Bean("inventoryPool")
    public ThreadPoolTaskExecutor inventoryPool() {
        var pool = new ThreadPoolTaskExecutor();
        pool.setCorePoolSize(5);
        pool.setMaxPoolSize(10);
        pool.setQueueCapacity(20);
        pool.setRejectedExecutionHandler(new ThreadPoolExecutor.CallerRunsPolicy());
        pool.setThreadNamePrefix("inventory-");
        pool.initialize();
        return pool;
    }

    @Bean("notificationPool")
    public ThreadPoolTaskExecutor notificationPool() {
        var pool = new ThreadPoolTaskExecutor();
        pool.setCorePoolSize(3);
        pool.setMaxPoolSize(5);
        pool.setQueueCapacity(100);     // Notifications can queue — low priority
        pool.setRejectedExecutionHandler(new ThreadPoolExecutor.DiscardOldestPolicy());
        pool.setThreadNamePrefix("notify-");
        pool.initialize();
        return pool;
    }

    @Bean
    public PaymentClient paymentClient(@Qualifier("paymentPool") ThreadPoolTaskExecutor pool) {
        var httpClient = HttpClient.newBuilder()
            .executor(pool.getThreadPoolExecutor())
            .build();
        return new PaymentClient(RestClient.builder()
            .requestFactory(new JdkClientHttpRequestFactory(httpClient))
            .build());
    }

    @Bean
    public InventoryClient inventoryClient(@Qualifier("inventoryPool") ThreadPoolTaskExecutor pool) {
        var httpClient = HttpClient.newBuilder()
            .executor(pool.getThreadPoolExecutor())
            .build();
        return new InventoryClient(RestClient.builder()
            .requestFactory(new JdkClientHttpRequestFactory(httpClient))
            .build());
    }
    // Payment service degrades → fills paymentPool only.
    // Inventory calls use inventoryPool — unaffected, still responds instantly.
}
```

```java
// Resilience4j Bulkhead — same principle without manual thread pools
// Configuration
resilience4j.bulkhead:
  instances:
    paymentGateway:
      maxConcurrentCalls: 10
      maxWaitDuration: 50ms   # Fail fast if thread not available within 50ms
    inventoryService:
      maxConcurrentCalls: 5
      maxWaitDuration: 100ms

// Usage
@Service
public class CheckoutService {
    private final Bulkhead paymentBulkhead;
    private final Bulkhead inventoryBulkhead;

    public OrderResult checkout(CheckoutRequest req) {
        // Concurrently reserve inventory and capture payment
        var inventoryFuture = CompletableFuture.supplyAsync(() ->
            Bulkhead.decorateSupplier(inventoryBulkhead, () -> inventory.reserve(req.items())).get()
        );
        var paymentFuture = CompletableFuture.supplyAsync(() ->
            Bulkhead.decorateSupplier(paymentBulkhead, () -> payment.charge(req.payment())).get()
        );

        var inventoryResult = inventoryFuture.join();
        var paymentResult = paymentFuture.join();

        return completeOrder(req, inventoryResult, paymentResult);
    }
}
```

**Expert Note**: Thread pool sizing is NOT guesswork. Profile your downstream: measure
p99 latency and throughput. A pool of `(target throughput × p99 latency)` threads is a
reasonable starting point. Queue capacity should be small for latency-sensitive calls
(fail fast) and larger for async/background calls (absorb bursts). Always set a
`RejectedExecutionHandler` — the default `AbortPolicy` surfaces the problem immediately
instead of silently piling up tasks.

---

## RP-3: Retry + Exponential Backoff + Jitter

**Pattern**: When a call fails due to a transient error, retry with increasing delay
between attempts. Add random jitter to prevent thundering herd problems where
many clients retry simultaneously. This is NOT a substitute for circuit breakers —
it addresses temporary blips, not systemic degradation.

**Mathematical basis**:

- **Exponential Backoff**: `delay = base × 2^(attempt-1)`, capped at `maxDelay`
- **Jitter**: `actualDelay = random(0, delay)` (full jitter) or
  `actualDelay = delay / 2 + random(0, delay / 2)` (equal jitter)

**Use when**: Calling services where transient failures are expected — temporary
network glitches, DNS resolution delays, brief GC pauses, leader election in progress.
Only retry when the operation is **idempotent** or the retry mechanism includes
idempotency keys.

### ❌ Wrong — Naive Retry

```java
public PaymentResult charge(PaymentRequest req) {
    for (int i = 0; i < 3; i++) {
        try {
            return paymentGateway.charge(req);
        } catch (Exception e) {
            log.warn("Attempt {} failed, retrying...", i + 1);
            Thread.sleep(1000); // Fixed delay — thundering herd
        }
    }
    throw new PaymentExhaustedException("All retries failed for " + req.orderId());
    // Problems:
    // 1. Retries immediately — no backoff. Downstream still under load.
    // 2. Fixed delay — if 1000 clients hit this, they ALL retry at T+1s simultaneously.
    // 3. No idempotency — retry after partial success = double charge.
    // 4. No max elapsed time — can retry forever.
}
```

### Root Cause

Fixed-delay retries synchronize the retry storm. When a downstream has a brief hiccup
that affects 10,000 concurrent requests, all 10,000 retry at exactly the same time,
turning a transient recovery into a prolonged self-DoS. Without jitter, every retry
reinforces the overload pattern.

### ✅ Expert Fix — Exponential Backoff with Full Jitter

```java
@Service
public class ResilientPaymentService {
    private final PaymentGateway gateway;
    private final IdempotencyStore idempotency;

    private static final int MAX_RETRIES = 3;
    private static final Duration BASE_DELAY = Duration.ofMillis(100);
    private static final Duration MAX_DELAY = Duration.ofSeconds(5);
    private static final Duration MAX_ELAPSED = Duration.ofSeconds(15);

    public PaymentResult charge(PaymentRequest req) {
        var deadline = Instant.now().plus(MAX_ELAPSED);
        var idempotencyKey = req.idempotencyKey();

        for (int attempt = 0; attempt <= MAX_RETRIES; attempt++) {
            try {
                var result = gateway.charge(req);
                idempotency.store(idempotencyKey, result);
                return result;
            } catch (Exception e) {
                if (!isRetryable(e) || attempt == MAX_RETRIES || Instant.now().isAfter(deadline)) {
                    throw new PaymentExhaustedException(req.orderId(), MAX_RETRIES, e);
                }
                try {
                    // Check idempotency before retrying — previous attempt may have succeeded
                    var cached = idempotency.get(idempotencyKey);
                    if (cached != null) {
                        log.info("Previous attempt succeeded, returning cached result for {}", idempotencyKey);
                        return cached;
                    }
                } catch (Exception ignored) {}

                var delay = calculateBackoff(attempt);
                log.warn("Payment attempt {} failed for order {}: {} — retrying in {}ms",
                    attempt + 1, req.orderId(), e.getMessage(), delay.toMillis());
                sleep(delay);
            }
        }
        throw new PaymentExhaustedException(req.orderId(), MAX_RETRIES, null);
    }

    private Duration calculateBackoff(int attempt) {
        var exponentialDelay = (long) (BASE_DELAY.toMillis() * Math.pow(2, attempt));
        var cappedDelay = Math.min(exponentialDelay, MAX_DELAY.toMillis());

        // Full jitter: random(0, cappedDelay)
        var jitteredDelay = ThreadLocalRandom.current().nextLong(cappedDelay + 1);

        return Duration.ofMillis(jitteredDelay);
        // attempt=0: delay ∈ [0, 100]ms
        // attempt=1: delay ∈ [0, 200]ms
        // attempt=2: delay ∈ [0, 400]ms
        // attempt=3: delay ∈ [0, 800]ms
        // With jitter, 1000 clients spread over the entire interval — no synchronized retry wave.
    }

    private boolean isRetryable(Exception e) {
        return e instanceof SocketTimeoutException
            || e instanceof ConnectException
            || e instanceof HttpServerErrorException ex
               && ex.getStatusCode().is5xxServerError();
        // 4xx errors are NOT retryable — retrying "bad request" always fails.
    }

    private void sleep(Duration duration) {
        try { Thread.sleep(duration.toMillis()); }
        catch (InterruptedException e) { Thread.currentThread().interrupt(); }
    }
}
```

```go
// Go equivalent — exponential backoff with jitter
func (s *PaymentService) Charge(ctx context.Context, req PaymentRequest) (*PaymentResult, error) {
    const (
        maxRetries = 3
        baseDelay  = 100 * time.Millisecond
        maxDelay   = 5 * time.Second
    )

    idempotencyKey := req.IdempotencyKey

    for attempt := 0; attempt <= maxRetries; attempt++ {
        result, err := s.gateway.Charge(ctx, req)
        if err == nil {
            s.idempotency.Store(ctx, idempotencyKey, result)
            return result, nil
        }

        if !isRetryable(err) || attempt == maxRetries {
            return nil, fmt.Errorf("charge payment %s: all retries exhausted: %w", req.OrderID, err)
        }

        if cached, _ := s.idempotency.Get(ctx, idempotencyKey); cached != nil {
            return cached, nil
        }

        // Full jitter: random in [0, min(2^attempt * base, max)]
        backoff := time.Duration(min(
            float64(maxDelay),
            float64(baseDelay)*math.Pow(2, float64(attempt)),
        ))
        jitter := time.Duration(rand.Int63n(int64(backoff) + 1)) // #nosec G404 — non-crypto use

        log.Printf("charge attempt %d failed: %v — retrying in %v", attempt+1, err, jitter)

        select {
        case <-time.After(jitter):
        case <-ctx.Done():
            return nil, ctx.Err()
        }
    }
    return nil, fmt.Errorf("charge payment %s: unreachable", req.OrderID)
}
```

**Expert Note**: Retry without idempotency is gambling with money. The most dangerous
failure mode is a timeout after the server has already processed the request but
before the client receives the response. A retry in this case processes the request
twice. Always require an `Idempotency-Key` header on retryable POST/PUT operations.
The exponent base of 2 is canonical, but in practice, some teams use base 3 for faster
spread. The key is the cap (`maxDelay`), not the base — cap at 5-10 seconds for
user-facing calls, 30-60 seconds for background jobs.

---

## RP-4: Rate Limiting

**Pattern**: Control the rate at which requests are accepted to protect the system from
being overwhelmed. Two essential algorithms:

- **Token Bucket**: A bucket holds `capacity` tokens, refilled at `rate` tokens/second.
  Each request consumes one token. If the bucket is empty, the request is rejected.
  Allows bursts up to `capacity` while enforcing a long-term rate.
- **Sliding Window Log**: Track timestamps of recent requests. For each new request,
  count how many requests occurred in the last `window` duration. Reject if the
  count exceeds `limit`. More precise than fixed-window but uses more memory.

**Use when**: Any public API endpoint, any authenticated endpoint per-user, any
service-to-service call where the upstream could send unbounded traffic. Rate
limiting is a defense at the system boundary — without it, any caller can DoS you.

### ❌ Wrong — No Rate Limiting

```java
@RestController
@RequestMapping("/api/orders")
public class OrderController {
    private final OrderService orderService;

    @PostMapping
    public Order create(@RequestBody CreateOrderRequest req) {
        return orderService.create(req);
        // No limit — malicious user sends 10,000 POSTs/second.
        // DB connection pool exhausted. Payment gateway thread pool exhausted.
        // Legitimate users get timeouts. Entire system degraded.
    }
}
```

### Root Cause

Every endpoint has a maximum sustainable throughput determined by its slowest
dependency. Without explicit enforcement, there is no backpressure. The system
accepts requests until it breaks, then breaks for everyone — including harmless
traffic that happens to share the same infrastructure.

### ✅ Expert Fix — Token Bucket Implementation

```java
public class TokenBucketRateLimiter {
    private final long capacity;
    private final double refillRate; // tokens per second
    private double tokens;
    private long lastRefillNanos;

    public TokenBucketRateLimiter(long capacity, long permitsPerSecond) {
        this.capacity = capacity;
        this.refillRate = (double) permitsPerSecond;
        this.tokens = capacity; // start full to allow initial burst
        this.lastRefillNanos = System.nanoTime();
    }

    public synchronized boolean tryAcquire() {
        refill();
        if (tokens >= 1.0) {
            tokens -= 1.0;
            return true;
        }
        return false;
    }

    public synchronized boolean tryAcquire(long permits) {
        refill();
        if (tokens >= permits) {
            tokens -= permits;
            return true;
        }
        return false;
    }

    private void refill() {
        long now = System.nanoTime();
        double elapsed = (now - lastRefillNanos) / 1_000_000_000.0;
        tokens = Math.min(capacity, tokens + elapsed * refillRate);
        lastRefillNanos = now;
    }
}
```

```java
// Sliding Window Log Rate Limiter
public class SlidingWindowRateLimiter {
    private final int limit;
    private final long windowMillis;
    private final Deque<Long> timestamps;

    public SlidingWindowRateLimiter(int limit, Duration window) {
        this.limit = limit;
        this.windowMillis = window.toMillis();
        this.timestamps = new ConcurrentLinkedDeque<>();
    }

    public synchronized boolean tryAcquire() {
        long now = System.currentTimeMillis();
        long cutoff = now - windowMillis;

        // Evict expired timestamps
        while (!timestamps.isEmpty() && timestamps.peekFirst() <= cutoff) {
            timestamps.pollFirst();
        }

        if (timestamps.size() < limit) {
            timestamps.offerLast(now);
            return true;
        }
        return false;
    }
}
```

```java
// Production-grade: layered rate limiting with Bucket4j
@Configuration
public class RateLimitConfig {

    @Bean
    public Filter rateLimitFilter(Bucket globalBucket) {
        return new OncePerRequestFilter() {
            @Override
            protected void doFilterInternal(HttpServletRequest request,
                    HttpServletResponse response, FilterChain chain)
                    throws ServletException, IOException {

                var apiKey = request.getHeader("X-API-Key");
                if (apiKey == null) {
                    response.setStatus(401);
                    response.getWriter().write("{\"error\":\"Missing API key\"}");
                    return;
                }

                // Layer 1: Global rate limit — protects the entire service
                if (!globalBucket.tryConsume(1)) {
                    response.setStatus(429);
                    response.setHeader("Retry-After", "5");
                    response.getWriter().write(
                        "{\"error\":\"Global rate limit exceeded\",\"retryAfter\":5}"
                    );
                    metrics.globalRateLimitHit.increment();
                    return;
                }

                // Layer 2: Per-API-key rate limit — protects fair usage per tenant
                var perKeyBucket = bucket4j.rateLimitForKey(apiKey);
                if (!perKeyBucket.tryConsume(1)) {
                    response.setStatus(429);
                    response.setHeader("Retry-After", "1");
                    response.getWriter().write(
                        "{\"error\":\"Rate limit exceeded for this API key\",\"retryAfter\":1}"
                    );
                    metrics.perKeyRateLimitHit.increment();
                    return;
                }

                // Layer 3: Per-endpoint rate limit — cost-expensive endpoints get stricter limits
                var endpoint = request.getRequestURI();
                var endpointBucket = bucket4j.rateLimitForEndpoint(endpoint);
                if (!endpointBucket.tryConsume(costFor(endpoint))) {
                    response.setStatus(429);
                    response.setHeader("Retry-After", "2");
                    response.getWriter().write(
                        "{\"error\":\"Endpoint rate limit exceeded\",\"retryAfter\":2}"
                    );
                    return;
                }

                chain.doFilter(request, response);
            }
        };
    }
}
```

**Expert Note**: Rate limiting is a backpressure mechanism. Always return HTTP 429
with a `Retry-After` header — this is the standard signal that allows well-behaved
clients to back off automatically. Token Bucket is preferred for APIs because it
allows bursts (up to bucket capacity) while maintaining a long-term average rate.
Sliding Window Log is more precise for strict enforcement but costs more memory
per key. In distributed deployments, use a centralized Redis-backed rate limiter
(`SET key value NX EX ttl` with Lua scripting for atomicity) or a consensus-based
algorithm like distributed token buckets.

---

## RP-5: Load Shedding

**Pattern**: When the system is overloaded, selectively reject or defer low-priority
requests to preserve capacity for critical ones. This is the last line of defense —
after retries, circuit breakers, and rate limiting have all been exhausted.

**Strategies**:

- **Priority queuing**: Assign priority levels to requests. Under load, process
  high-priority first, reject or defer low-priority.
- **Graceful degradation**: Drop non-critical features (recommendations, analytics
  enrichment) while keeping core functionality (order placement, payment).
- **Adaptive LIFO**: Under low load, process FIFO (fair). Under high load, switch to
  LIFO — serve the newest requests because the oldest are likely already timed out
  on the client side.

**Use when**: The system is saturated and all upstream protections (rate limiting,
circuit breakers) have failed or were insufficient. Load shedding is the final
decision: *what should we keep alive when we can't keep everything alive?*

### ❌ Wrong — No Priority Differentiation

```java
@RestController
public class UnifiedController {
    private final ExecutorService executor = Executors.newFixedThreadPool(100);

    @PostMapping("/api/orders") // Critical — revenue
    public CompletableFuture<Order> createOrder(@RequestBody OrderRequest req) {
        return CompletableFuture.supplyAsync(() -> orderService.create(req), executor);
    }

    @GetMapping("/api/reports") // Non-critical — analytics dashboard
    public CompletableFuture<Report> getReport(@RequestParam String query) {
        return CompletableFuture.supplyAsync(() -> reportService.generate(query), executor);
        // Analytics query takes 10s, uses 50 threads simultaneously.
        // During peak: order creation blocked behind analytics.
        // Revenue-critical operations compete equally with cosmetic features.
    }
}
```

### Root Cause

All requests are treated as equal. When the system saturates, the critical path
(order placement, payment) competes on equal footing with non-critical features
(analytics exports, batch reports). The system fails in the worst possible way:
it drops revenue-generating traffic while serving internal dashboards.

### ✅ Expert Fix — Priority Queue with Load Shedding

```java
public enum RequestPriority {
    CRITICAL(0),  // payment, order placement — revenue
    HIGH(1),      // authenticated user queries
    NORMAL(2),    // anonymous browsing
    LOW(3),       // analytics exports, batch reports
    BEST_EFFORT(4); // prefetch, speculative enrichment
}

public class PriorityAwareTask implements Comparable<PriorityAwareTask> {
    private final RequestPriority priority;
    private final long arrivalTime;
    private final Runnable task;

    @Override
    public int compareTo(PriorityAwareTask other) {
        int priorityCmp = this.priority.compareTo(other.priority);
        if (priorityCmp != 0) return priorityCmp; // lower enum ordinal = higher priority
        return Long.compare(this.arrivalTime, other.arrivalTime); // FIFO within same priority
    }
}
```

```java
@Component
public class PriorityWorkQueue {
    private final PriorityBlockingQueue<PriorityAwareTask> queue;
    private final ThreadPoolExecutor executor;
    private final int highWatermark;
    private final int lowWatermark;

    public PriorityWorkQueue(int coreThreads, int maxThreads, int queueCapacity) {
        this.queue = new PriorityBlockingQueue<>(queueCapacity);
        this.highWatermark = (int) (queueCapacity * 0.8); // start shedding at 80%
        this.lowWatermark = (int) (queueCapacity * 0.5);  // stop shedding at 50%
        this.executor = new ThreadPoolExecutor(
            coreThreads, maxThreads, 60, TimeUnit.SECONDS,
            new SynchronousQueue<>(), // no unbounded queue on executor itself
            new ThreadPoolExecutor.CallerRunsPolicy()
        );
    }

    public <T> CompletableFuture<T> submit(RequestPriority priority, Supplier<T> task) {
        if (shouldShed(priority)) {
            metrics.loadShed.increment();
            return CompletableFuture.failedFuture(
                new LoadShedException("System overloaded, shedding " + priority + " request")
            );
        }

        var future = new CompletableFuture<T>();
        queue.offer(new PriorityAwareTask(priority, System.nanoTime(), () -> {
            try {
                future.complete(task.get());
            } catch (Exception e) {
                future.completeExceptionally(e);
            }
        }));
        drainQueue();
        return future;
    }

    private boolean shouldShed(RequestPriority priority) {
        int queueSize = queue.size();
        if (queueSize < highWatermark) return false;

        // At high watermark: shed BEST_EFFORT
        if (queueSize >= highWatermark && priority == RequestPriority.BEST_EFFORT) return true;

        // At critical: shed LOW and below
        if (queueSize >= queue.remainingCapacity() * 0.95
                && priority.compareTo(RequestPriority.LOW) >= 0) return true;

        return false;
        // CRITICAL requests are never shed — better to queue them than reject.
    }

    private void drainQueue() {
        var task = queue.poll();
        while (task != null && executor.getActiveCount() < executor.getMaximumPoolSize()) {
            executor.execute(task.task());
            task = queue.poll();
        }
        if (task != null) {
            queue.offer(task); // put it back if no thread available
        }
    }
}
```

```java
// Graceful degradation: drop features progressively under load
@Component
public class ProductPageService {
    private final ProductRepository productRepo;
    private final RecommendationService recommendations;
    private final ReviewService reviews;
    private final MetricsService metrics;

    public ProductPage buildPage(Long productId, SystemHealth health) {
        var product = productRepo.findById(productId).orElseThrow();

        switch (health) {
            case HEALTHY:
                return ProductPage.full(product,
                    recommendations.getForProduct(productId), // expensive
                    reviews.getReviews(productId),             // expensive
                    reviews.getRating(productId));             // expensive

            case DEGRADED:
                return ProductPage.full(product,
                    recommendations.getForProduct(productId).subList(0, 5), // limited
                    reviews.getReviews(productId).subList(0, 10),           // limited
                    reviews.getCachedRating(productId));                    // stale OK

            case OVERLOADED:
                return ProductPage.minimal(product); // name, price, stock only — no enrichment

            case CRITICAL:
                return ProductPage.static(product); // from static cache — may be stale
        }
        return null;
    }
}
```

**Expert Note**: Load shedding is a deliberate sacrifice. You are choosing to fail some
requests so that others succeed. The most important decision is the priority
classification — it must align with business value, not technical convenience. A
common mistake: treating "internal API call" as low priority when it's the only
thing keeping the customer-facing feature alive. Always test your shedding logic
under production-level load. Chaos engineering (actively injecting overload) is
the only way to validate that your priority hierarchy is correct.

---

## RP-6: Timeout Propagation (Deadline)

**Pattern**: Every downstream call in a chain has a maximum total time budget. This
budget is carried from the entry point through every hop, decrementing as each
hop consumes time. When the deadline expires, all remaining work is abandoned —
no zombie computation, no orphaned side effects.

**Mechanism**:

- Each incoming request carries a **deadline** (absolute timestamp).
- Before calling a downstream, calculate `remaining = deadline - now()`.
- If `remaining <= 0`, fast-fail — don't even make the call.
- Pass `remaining` as the downstream call timeout or as a `grpc-timeout` /
  `X-Request-Deadline` header.

**Use when**: Any request that traverses more than one service. Without deadline
propagation, each hop sets its own timeout independently, potentially waiting
30s on a request whose original caller timed out 28 seconds ago.

### ❌ Wrong — Independent Per-Hop Timeouts

```java
// Entry point: 10s timeout
@GetMapping("/api/checkout")
public OrderResult checkout(@RequestBody CheckoutRequest req) {
    return orderService.checkout(req); // user expects response within 10s
}

// OrderService: 8s timeout on payment
@Service
public class OrderService {
    public OrderResult checkout(CheckoutRequest req) {
        var inventory = inventoryClient.reserve(req.items()); // 3s timeout
        var payment = paymentClient.charge(req.payment());    // 8s timeout
        // inventory took 2.8s → remaining budget: 5.2s
        // But paymentClient has its own 8s timeout — no awareness of the remaining budget.
        // Payment call takes 7s — succeeds, but total elapsed: 2.8s + 7s = 9.8s
        // shipping still needs to be called with 0.2s remaining.
        // Shipping times out — partial order state with reserved inventory, captured payment.
    }
}
```

### Root Cause

Each service independently chooses its timeout. No service knows how much of the
original budget has already been consumed by upstream processing. The result:
work continues long after the end user has given up (received a timeout error),
wasting resources on all downstream services. In payment scenarios, this means
charging customers for orders they'll never receive.

### ✅ Expert Fix — Deadline Propagation

```java
// Deadline context carries the absolute deadline through the call chain
public record DeadlineContext(Instant deadline) {
    private static final String HEADER = "X-Request-Deadline";

    public static DeadlineContext fromRequest(HttpServletRequest request) {
        var header = request.getHeader(HEADER);
        if (header != null) {
            return new DeadlineContext(Instant.parse(header));
        }
        // Entry point: set deadline from client timeout
        var defaultTimeout = Duration.ofSeconds(30);
        return new DeadlineContext(Instant.now().plus(defaultTimeout));
    }

    public Duration remaining() {
        return Duration.between(Instant.now(), deadline);
    }

    public boolean isExpired() {
        return Instant.now().isAfter(deadline);
    }

    public void propagateTo(HttpHeaders headers) {
        headers.set(HEADER, deadline.toString());
    }

    public Duration remainingOr(Duration fallback) {
        var r = remaining();
        return r.isNegative() || r.isZero() ? fallback : r;
    }
}
```

```java
// Filter captures deadline from incoming request, injects into context
@WebFilter
public class DeadlineFilter implements Filter {
    @Override
    public void doFilter(ServletRequest req, ServletResponse res, FilterChain chain)
            throws IOException, ServletException {
        var httpReq = (HttpServletRequest) req;
        var deadline = DeadlineContext.fromRequest(httpReq);
        DeadlineHolder.set(deadline);
        try {
            chain.doFilter(req, res);
        } finally {
            DeadlineHolder.clear();
        }
    }
}

// ThreadLocal holder — scoped to request thread
public class DeadlineHolder {
    private static final ThreadLocal<DeadlineContext> ctx = new ThreadLocal<>();

    public static void set(DeadlineContext deadline) { ctx.set(deadline); }
    public static DeadlineContext get() { return ctx.get(); }
    public static void clear() { ctx.remove(); }
}
```

```java
@Service
public class ResilientPaymentClient {
    private final RestClient restClient;

    public PaymentResult charge(PaymentRequest req) {
        var deadline = DeadlineHolder.get();

        if (deadline != null && deadline.isExpired()) {
            throw new DeadlineExceededException(
                "Deadline " + deadline.deadline() + " exceeded before calling payment gateway"
            );
        }

        // Calculate remaining budget — NEVER exceed it
        var timeout = deadline != null
            ? deadline.remainingOr(Duration.ofSeconds(5))
            : Duration.ofSeconds(5);

        if (timeout.toMillis() < 100) {
            throw new DeadlineExceededException(
                "Insufficient time remaining: " + timeout.toMillis() + "ms"
            );
        }

        var headers = new org.springframework.http.HttpHeaders();
        if (deadline != null) {
            deadline.propagateTo(headers);
        }

        return restClient.post()
            .uri("http://payment-gateway/api/charge")
            .headers(h -> h.addAll(headers))
            .body(req)
            .httpRequest(request -> {
                // Inject deadline into the actual HTTP client timeout
                var nativeRequest = (HttpURLConnection) request.getNativeRequest();
                nativeRequest.setConnectTimeout((int) Math.min(timeout.toMillis(), 3000));
                nativeRequest.setReadTimeout((int) timeout.toMillis());
            })
            .retrieve()
            .body(PaymentResult.class);
    }
}
```

```go
// Go — context-based deadline propagation (native gRPC pattern)
func (s *CheckoutService) Checkout(ctx context.Context, req *CheckoutRequest) (*OrderResult, error) {
    deadline, ok := ctx.Deadline()
    if ok {
        remaining := time.Until(deadline)
        if remaining <= 0 {
            return nil, status.Error(codes.DeadlineExceeded, "deadline exceeded before processing")
        }
        log.Printf("checkout deadline: %v remaining", remaining)
    }

    // Reserve inventory — another 30% of remaining budget
    inventoryCtx, inventoryCancel := s.subContext(ctx, 0.30)
    defer inventoryCancel()
    inventory, err := s.inventoryClient.Reserve(inventoryCtx, req.Items)
    if err != nil {
        return nil, fmt.Errorf("reserve inventory: %w", err)
    }

    // Capture payment — 50% of remaining budget
    paymentCtx, paymentCancel := s.subContext(ctx, 0.50)
    defer paymentCancel()
    payment, err := s.paymentClient.Charge(paymentCtx, req.Payment)
    if err != nil {
        // Compensate inventory reservation
        s.inventoryClient.Release(context.Background(), req.Items)
        return nil, fmt.Errorf("capture payment: %w", err)
    }

    // Create shipping — 20% of remaining budget
    shippingCtx, shippingCancel := s.subContext(ctx, 0.20)
    defer shippingCancel()
    delivery, err := s.shippingClient.Create(shippingCtx, req.Address, inventory.Items)
    if err != nil {
        s.paymentClient.Refund(context.Background(), payment.TransactionID)
        s.inventoryClient.Release(context.Background(), req.Items)
        return nil, fmt.Errorf("create delivery: %w", err)
    }

    return &OrderResult{
        OrderID:   uuid.New().String(),
        Inventory: inventory,
        Payment:   payment,
        Delivery:  delivery,
    }, nil
}

// subContext creates a child context with a proportional slice of the remaining deadline
func (s *CheckoutService) subContext(parent context.Context, proportion float64) (context.Context, context.CancelFunc) {
    deadline, ok := parent.Deadline()
    if !ok {
        return context.WithCancel(parent)
    }
    remaining := time.Until(deadline)
    slice := time.Duration(float64(remaining) * proportion)
    return context.WithTimeout(parent, slice)
}
```

```java
// Server-side: check deadline BEFORE starting expensive work
@PostMapping("/api/reports/export")
public ResponseEntity<?> exportReport(@RequestBody ReportRequest req) {
    var deadline = DeadlineHolder.get();

    // Fast-check: if less than 2s remaining, reject immediately
    if (deadline != null && deadline.remaining().compareTo(Duration.ofSeconds(2)) < 0) {
        return ResponseEntity.status(503)
            .header("Retry-After", "5")
            .body(Map.of("error", "Insufficient time remaining for export"));
    }

    // During processing: periodically check deadline
    var batch = reportRepo.findDataBatch(req.query(), req.filters());
    var result = new ArrayList<ReportRow>();

    for (var page : batch) {
        if (deadline != null && deadline.isExpired()) {
            log.warn("Deadline exceeded during report generation — returning partial result");
            break; // return partial data — better than nothing
        }
        result.addAll(processPage(page));
    }

    return ResponseEntity.ok(new PartialReport(result, result.size()));
}
```

**Expert Note**: Deadline propagation converts independent per-hop timeouts into a
coordinated global budget. The key insight: a request that takes 10 seconds
end-to-end should never spend 5 seconds in hop 1 and then 8 seconds (from its own
timeout) in hop 2. The deadline ensures that if hop 1 was slow, hop 2 knows it and
adjusts. In gRPC ecosystems, this is built-in — the `grpc-timeout` header is
automatically decremented at each hop. In REST ecosystems, you must implement it
manually via headers. The rule: every service MUST propagate the deadline to every
synchronous downstream call. No exceptions.

---

## Quick Resilience Checklist

Before deploying a distributed system:

- [ ] Every external call has a **Circuit Breaker** with configured thresholds and fallback?
- [ ] Every downstream dependency has its own **Bulkhead** (thread pool or semaphore)?
- [ ] Every retryable operation uses **Exponential Backoff + Jitter**?
- [ ] Every retryable mutation carries an **Idempotency Key**?
- [ ] Every retry only targets **retryable errors** (5xx, timeouts — NOT 4xx)?
- [ ] Every API endpoint has **Rate Limiting** (global + per-client + per-endpoint)?
- [ ] **Load Shedding** is configured with business-aligned priority levels?
- [ ] Every service propagates **Deadline** headers to all synchronous downstream calls?
- [ ] Every service checks the **deadline before starting expensive work**?
- [ ] Chaos engineering exercises validated all six patterns under production load?
