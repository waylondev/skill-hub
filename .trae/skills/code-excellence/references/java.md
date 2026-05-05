# Java Best Practices (21+)

## Purpose

This reference encodes **Java‑specific** best practices that, combined with
the parent `code-excellence` skill, guide AI to produce production‑grade,
idiomatic Java code. For Spring Boot framework guidance, see `springboot.md`.

---

## Java 21 Language Idioms

### Records for DTOs & Value Objects
```java
record Point(int x, int y) {}
```
- Immutability, `equals`, `hashCode`, `toString` — all auto‑generated.
- Use for DTOs, value objects, and API responses. Not for JPA entities.
- Combine with `@Builder` (Lombok) or manual builder for complex construction.

### Sealed Classes for Closed Hierarchies
```java
sealed interface Result<T> permits Success, Failure {}
record Success<T>(T data) implements Result<T> {}
record Failure(String message) implements Result<Nothing> {}
```
- The compiler enforces exhaustive handling in `switch` expressions.
- Ideal for state machines, algebraic data types, and result types.

### Pattern Matching for instanceof (16+, enhanced 21)
```java
if (obj instanceof String s && s.length() > 0) {
    System.out.println(s.toUpperCase());
}
```
- Eliminates the explicit cast. The binding variable `s` is scoped to the `if` block.

### Pattern Matching for switch (21+)
```java
String description = switch (obj) {
    case Integer i && i > 0 -> "positive integer";
    case Integer i && i < 0 -> "negative integer";
    case String s              -> "string: " + s;
    case null                  -> "null value";
    default                    -> "unknown type";
};
```
- Replaces long `if‑else` chains. Compiler checks exhaustiveness for sealed types.
- Guarded patterns (`&&`) add conditions without nested `if`.

### Record Patterns (21+)
```java
if (point instanceof Point(int x, int y)) {
    System.out.println(x + ", " + y);
}

// Nested destructuring
if (line instanceof Line(Point(int x1, int y1), Point(int x2, int y2))) {
    // use x1, y1, x2, y2 directly
}
```
- Destructure records directly in pattern matching without chained accessors.

### Virtual Threads (21+)
```java
try (var executor = Executors.newVirtualThreadPerTaskExecutor()) {
    executor.submit(() -> blockingIoCall());
    executor.submit(() -> anotherBlockingIoCall());
}
```
- Lightweight threads (not 1:1 with OS threads). Millions can coexist.
- **Rule**: Use virtual threads for I/O‑bound tasks. Use platform threads for CPU‑bound.
- Never pool virtual threads — they are cheap and disposable by design.
- For structured concurrency, use `StructuredTaskScope` (preview in 21).

### Text Blocks (15+)
```java
String json = """
    {
        "name": "%s",
        "age": %d
    }
    """.formatted(name, age);
```
- Use for SQL, JSON, HTML, or any multi‑line string. No more concatenation or escaping.

### SequencedCollection (21+)
```java
list.getFirst();
list.getLast();
list.addFirst(element);
list.addLast(element);
list.reversed();
```
- Unified API across `List`, `SortedSet`, `LinkedHashSet`, `Deque`.
- Avoids scattered calls to `list.get(0)`, `list.get(list.size() - 1)`.

### Immutable Collections
```java
List.of("a", "b", "c");
Set.of(1, 2, 3);
Map.of("key", "value", "key2", "value2");
```
- Returns truly immutable collections (not just unmodifiable views).
- For >10 elements, use `Map.ofEntries(...)` or `List.copyOf(collection)`.

---

## Optional

```java
Optional<User> findById(Long id);

// Do this
var user = repository.findById(id)
    .orElseThrow(() -> new NotFoundException("User not found: " + id));

// Never do this
Optional<String> getField() { ... }           // not as field type
void process(Optional<String> param) { ... }  // not as parameter
```
- Return `Optional` from methods that may produce no result (repository lookups).
- **Never** use `Optional` as a field, constructor parameter, or collection element.
- Prefer `orElseThrow` over `get()` — it carries an explanatory exception.

---

## Stream API

```java
var names = users.stream()
    .filter(u -> u.isActive())
    .map(User::name)
    .toList();
```
- Use for simple filter‑map‑collect pipelines.
- **Fall back to loops** when: the logic has checked exceptions, multiple mutable accumulators, or deeply nested conditions. Streams are not always the right answer.

---

## var for Local Variables

```java
var users = new ArrayList<User>();          // OK — type is obvious
var result = service.process(data);         // risky — what does it return?
```
- Use `var` when the right‑hand side makes the type obvious.
- Avoid `var` when the type conveys important domain meaning and is not obvious from context.

---

## Null Handling

- Avoid returning `null` from public methods. Return `Optional` or throw.
- Use `Objects.requireNonNull(param, "message")` for parameter validation.
- For nullable internal fields, annotate with `@Nullable` and `@NonNull` (JSpecify or checker‑framework).

---

## Testing

- **JUnit 5** — `@Test`, `@DisplayName`, `@Nested`, `@ParameterizedTest`.
- **AssertJ** for fluent assertions — `assertThat(result).isNotNull().extracting(User::name).isEqualTo("John")`.
- **Mockito** — `when(...).thenReturn(...)`, `verify(...)`. Prefer `@ExtendWith(MockitoExtension.class)`.
- **Test behaviour, not implementation** — test through public APIs, not internal method calls.

---

## How to Use This Reference

1. Apply `code-excellence` first for universal design principles.
2. Use this reference for Java‑specific idioms and syntax choices.
3. If using Spring Boot, also consult `springboot.md`.
4. For deeper understanding, refer to "Effective Java" (Joshua Bloch, 3rd edition) and the Java 21 language specification.
