# Java Best Practices (21+) — Expert Level

## Purpose

This reference encodes **Java‑specific expert practices** that, combined with
the parent `code-excellence` skill and its pattern catalog, guide AI to produce
production‑grade, idiomatic Java code. For Spring Boot framework guidance, see `springboot.md`.

---

## Java 21 Language Idioms

### Records for DTOs & Value Objects
```java
record Point(int x, int y) {}
```
- Immutability, `equals`, `hashCode`, `toString` — all auto‑generated.
- Use for DTOs, value objects, and API responses. Not for JPA entities.
- Records are `final` and cannot be subclassed — a feature, not a limitation.

### Sealed Classes for Closed Hierarchies
```java
sealed interface Result<T> permits Success, Failure {}
record Success<T>(T data) implements Result<T> {}
record Failure(String message) implements Result<T> {}
```
- Compiler enforces exhaustive handling in switch expressions. Adding a new variant forces a compilation error in every switch — this is the safety guarantee.

### Pattern Matching for switch (21+)
```java
String text = switch (obj) {
    case Integer i && i > 0  -> "positive: " + i;
    case Integer i && i < 0  -> "negative: " + i;
    case String s             -> "string: " + s;
    case null                 -> "null";
    default                   -> "unknown";
};
```
- Guarded patterns (`&&`) eliminate nested conditions. `null` is handled as a case, not a NullPointerException waiting to happen.

### Record Patterns (21+)
```java
if (order instanceof Order(Long id, Status status, _, Money total)) {
    // id, status, total extracted. _ ignores the third component.
}
```

### Virtual Threads (21+)
```java
try (var executor = Executors.newVirtualThreadPerTaskExecutor()) {
    var futures = tasks.stream()
        .map(t -> executor.submit(() -> process(t)))
        .toList();
    // Each task on a virtual thread. Platform threads not exhausted.
}
```
- **Never pool virtual threads**. They are not a scarce resource.
- Virtual threads are **carrier-mounted**: when a virtual thread blocks on I/O, it unmounts from the carrier platform thread, freeing it for other virtual threads.
- **Avoid synchronized blocks with virtual threads** — they pin the carrier thread. Use `ReentrantLock` instead.
- For structured concurrency, use `StructuredTaskScope` (preview in 21, stable in future).

### SequencedCollection (21+)
```java
list.getFirst(); list.getLast(); list.reversed();
linkedHashSet.getFirst(); linkedHashSet.getLast();
deque.addFirst(e); deque.addLast(e);
```

---

## JVM Expertise

### Garbage Collection Decision

```
Heap < 4GB, latency-tolerant            → G1GC (default since Java 9)
Heap < 4GB, latency-sensitive           → G1GC with -XX:MaxGCPauseMillis=100
Heap 4-64GB, latency-sensitive          → G1GC (tune region size)
Heap > 64GB OR extremely low latency    → ZGC (-XX:+UseZGC)
Extremely high throughput, batch jobs    → ParallelGC
```

**When to tune GC**: Only when GC pause duration exceeds your SLO or GC consumes >5% CPU in production monitoring. Premature GC tuning is cargo cult.

### JIT Watch Points

- **Warm-up matters**: The first 10,000 invocations of a method run in the interpreter or C1. Only after that do you get C2-optimized code. Microbenchmarks that don't warm up are meaningless.
- **Inlining budget**: Methods > 35 bytes of bytecode may not be inlined. Deep call stacks can break inlining. Flat code sometimes outperforms elegant decomposition for this reason alone. But don't optimize for this preemptively — profile first.
- **Escape analysis**: Objects that don't escape their creating method may be allocated on the stack instead of the heap. This means `new Object()` inside a hot loop isn't necessarily expensive.

### Memory Model Essentials

```java
// volatile: writes happen-before subsequent reads (across threads)
private volatile boolean running = true;
// Thread A: running = false; → Thread B sees false immediately

// final: guaranteed to be visible after construction completes
private final List<String> items; // safely published even without synchronization
```

**Rule**: For simple flags shared between threads, `volatile` is sufficient. For compound state, use `AtomicReference`, `synchronized`, or `Lock`.

---

## Deep Concurrency

### CompletableFuture Composition
```java
CompletableFuture<Order> orderFuture = findOrder(id);
CompletableFuture<Payment> paymentFuture = findPayment(id);

// Combine independent futures
CompletableFuture<OrderDetail> detail =
    orderFuture.thenCombine(paymentFuture, (o, p) -> new OrderDetail(o, p));

// Timeout — the single most underused feature
var result = future
    .orTimeout(2, TimeUnit.SECONDS)
    .exceptionally(e -> fallback());
```

### StampedLock for Read-Heavy Workloads
```java
class OptimisticCache {
    private final StampedLock lock = new StampedLock();
    private Map<String, User> data = new HashMap<>();

    User get(String key) {
        long stamp = lock.tryOptimisticRead();
        User user = data.get(key);
        if (!lock.validate(stamp)) {
            stamp = lock.readLock();
            try { user = data.get(key); }
            finally { lock.unlockRead(stamp); }
        }
        return user;
    }
}
```

### Thread Pool Sizing

```
I/O-bound (database calls, HTTP requests):
  threads = coreCount * 2 * (1 + waitTime / computeTime)
  Example: 8 cores, 50ms compute, 200ms wait → 8 * 2 * (1 + 4) = 80

CPU-bound: threads = coreCount + 1

Virtual threads: NO sizing. Unlimited.
```

---

## Performance Analysis Methodology

### The Correct Sequence
1. **Set a performance target** (P99 latency < 200ms). Without a target, optimization is infinite.
2. **Measure the current state** (production metrics, not local microbenchmarks).
3. **Profile** to find the bottleneck (async-profiler for CPU, JFR for allocation, GC logs for pauses).
4. **Hypothesize** a fix.
5. **Measure again**.
6. **Repeat** until target met, then **stop**.

### Production Profiling
```bash
# CPU profiling (async-profiler)
java -agentpath:async-profiler/lib/libasyncProfiler.so=start,event=cpu,file=cpu.svg ...

# JFR (Java Flight Recorder) — built-in, low overhead
java -XX:StartFlightRecording:filename=recording.jfr,duration=60s ...

# Heap dump on OOM
java -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=/dumps/
```

**Expert signal**: If you are guessing about performance, you are wrong. Profilers are not optional.

---

## Date/Time: Never Use java.util.Date

```java
Instant now = Instant.now();
ZonedDateTime userTime = now.atZone(ZoneId.of("Asia/Shanghai"));
LocalDate local = userTime.toLocalDate();

Duration duration = Duration.between(start, end);  // time-based
Period period = Period.between(startDate, endDate); // date-based
```

- Always store in UTC. Convert to user time zone at the presentation layer.
- Duration serialization: use ISO-8601 format (`PT30M`) or milliseconds. Never format as "30 minutes".

---

## Testing — Expert Level

### Property-Based Testing (jqwik)
```java
@Property
void anyListReversalIsInvolutive(@ForAll List<Integer> list) {
    var reversed = new ArrayList<>(list);
    Collections.reverse(reversed);
    Collections.reverse(reversed);
    assertThat(reversed).isEqualTo(list);
}
// Tests the property for HUNDREDS of randomly generated lists automatically
```

### Mutation Testing
Run Pitest to verify your tests actually catch bugs:
```bash
mvn org.pitest:pitest-maven:mutationCoverage
```
If a mutant survives (test still passes after code is mutated), the test or code is weak.

---

## How to Use This Reference

1. Apply `code-excellence` SKILL.md first for the operation pipeline.
2. Consult `decision-trees.md` for design choices.
3. Use this reference for Java‑specific implementation.
4. If using Spring Boot, also consult `springboot.md`.
5. For deeper understanding, refer to "Effective Java" (Bloch, 3rd edition) and "Java Concurrency in Practice" (Goetz).
