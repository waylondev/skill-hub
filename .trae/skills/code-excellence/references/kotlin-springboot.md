# Kotlin & Spring Boot Best Practices

## Purpose

This reference encodes **Kotlin‑ and Spring‑Boot‑specific** best practices that,
combined with the parent `code-excellence` skill, guide AI to produce
production‑grade, idiomatic Kotlin code.

---

## Kotlin Language Idioms

- **Data classes for DTOs / value objects** – `data class User(val id: Long, val name: String)`
  gives `equals`, `hashCode`, `toString`, and `copy` for free.
- **`val` over `var`** – Prefer immutability. Use `var` only when mutation
  is truly necessary.
- **Null safety** – Use `?`, `?:`, and `!!` (sparingly). Never return `null`
  from a function that should always produce a value; use `Result` or a
  sealed class instead.
- **Extension functions** – Add behaviour to existing types without
  inheritance. Keep them focused and discoverable.
- **Sealed classes / interfaces** – Model restricted hierarchies (e.g.
  `sealed class Result<out T> { data class Success<T>(val data: T) : Result<T>(); data class Error(val message: String) : Result<Nothing>() }`).
- **`when` expression** – Use exhaustive `when` with sealed classes to
  guarantee all cases are handled.
- **Scope functions** (`let`, `run`, `with`, `apply`, `also`) – Use them
  to reduce temporary variables, but don't over‑nest. Prefer `?.let { }`
  for null‑safe transformations.
- **Collections API** – `map`, `filter`, `fold`, `groupBy` are your friends.
  Use sequences for large, multi‑step transformations.

---

## Spring Boot with Kotlin

### Dependency Injection
- **Constructor injection with `val`** – `class OrderService(private val repo: OrderRepository)`
  is concise and immutable.
- **No need for `@Autowired`** on a single constructor – Spring Boot
  automatically wires it.

### Configuration
- **`@ConfigurationProperties` with data classes** – `@ConfigurationProperties(prefix = "app") data class AppProperties(val name: String, val timeout: Duration)`
  gives type‑safe, immutable configuration.

### Bean Definitions
- Use **`@Configuration` + `@Bean`** with Kotlin's concise syntax.
- Leverage **DSL‑style bean registration** when using the Kotlin functional
  bean definition API.

### Exception Handling
- Use **`@ControllerAdvice`** with sealed class hierarchies for error
  responses.
- Return a consistent error body (e.g. `data class ApiError(val code: String, val message: String)`).

### Validation
- Use **Bean Validation** annotations on data classes.
- Validate with `@Valid` in controller parameters.

---

## Coroutines & Reactive

- **Use coroutines for asynchronous, non‑blocking code** – Prefer
  `suspend` functions over `Mono`/`Flux` when using Spring WebFlux with
  Kotlin.
- **`kotlinx-coroutines-reactor`** bridges coroutines and Reactor types.
- **Structured concurrency** – Use `coroutineScope` or `supervisorScope`
  to manage child coroutines. Never use `GlobalScope`.
- **`runBlocking` only at the application boundary** (e.g. in tests or
  main functions).

---

## JPA / Hibernate with Kotlin

- **Use `@Entity` on regular classes, not data classes** – Data classes
  generate `equals`/`hashCode` based on all properties, which can cause
  issues with Hibernate proxies. Use a regular class with `var` properties
  and manually override `equals`/`hashCode` based on the `@Id`.
- **`lateinit var` for lazy‑loaded associations** – Avoids nullable types
  for mandatory relationships.
- **DTO projections** – Use interface‑based projections or map to data
  classes in the service layer.

---

## Testing

- **Kotest or JUnit 5** – Kotest provides Kotlin‑native testing styles
  (`StringSpec`, `ShouldSpec`). JUnit 5 works well too.
- **MockK for mocking** – `mockk`, `every`, `verify` are idiomatic for
  Kotlin (supports coroutines, extension functions, and objects).
- **Testcontainers** for integration tests.
- **`@SpringBootTest`** with `@TestConstructor(autowireMode = AutowireMode.ALL)`
  for constructor injection in tests.

---

## Production Patterns

- **Structured logging with `kotlin-logging`** – `private val logger = KotlinLogging.logger {}`
  gives a lightweight, idiomatic logger.
- **Micrometer for metrics** – Same as Java.
- **Graceful shutdown** – Enable `server.shutdown=graceful`.
- **Health checks** – Implement `HealthIndicator` in Kotlin.

---

## Package Structure

Same as Java: **package‑by‑feature**.

```
com.example.order
├── Order.kt
├── OrderRepository.kt
├── OrderService.kt
├── OrderController.kt
├── OrderDto.kt
└── OrderMapper.kt
```

---

## How to Use This Reference

1. Apply `code-excellence` first.
2. Use this reference for Kotlin / Spring Boot specifics.
3. Refer to "Kotlin in Action" and the official Spring Boot Kotlin
   documentation for deeper dives.
