# Java & Spring Boot Best Practices

## Purpose

This reference encodes **Java‑ and Spring‑Boot‑specific** best practices that,
combined with the parent `code-excellence` skill, guide AI to produce
production‑grade, idiomatic Java code.

---

## Java Language Idioms (17+)

- **Records for DTOs / value objects** – `record Point(int x, int y) {}`
  gives immutability, `equals`, `hashCode`, and `toString` for free.
- **Sealed classes for closed type hierarchies** – Use `sealed` to restrict
  which classes can extend a base type. Great for modelling state machines
  or algebraic data types.
- **Pattern matching for `instanceof`** – `if (obj instanceof String s && s.length() > 0)`
  eliminates the cast and makes the code flatter.
- **Text blocks for multi‑line strings** – Use `"""..."""` for SQL, JSON,
  or HTML embedded in code.
- **`List.of`, `Set.of`, `Map.of`** for small immutable collections.
- **`Optional` for return types that may be absent** – Never use `Optional`
  as a field or method parameter. Return `Optional` from repository / service
  methods that may not find a result.
- **Stream API with care** – Use streams for simple transformations and
  filtering. Fall back to loops when the logic becomes complex or needs
  checked exceptions.
- **`var` for local variables when the type is obvious** – `var users = new ArrayList<User>();`
  reduces noise without sacrificing readability.

---

## Spring Boot Conventions

### Dependency Injection
- **Constructor injection only** – It makes dependencies explicit, supports
  immutability (`final` fields), and simplifies unit testing.
- **Do not use `@Autowired` on fields** – Field injection hides dependencies
  and makes testing harder.
- **Use `@ConfigurationProperties`** for type‑safe configuration binding
  instead of scattering `@Value` annotations.

### Bean Declaration
- Prefer **Java configuration** (`@Configuration` + `@Bean`) over XML.
- Use **`@ComponentScan`** sparingly; explicit configuration is easier to
  reason about in large projects.

### Transaction Management
- **`@Transactional` on service methods**, not on controllers or repositories.
- **Be aware of self‑invocation** – Calling a `@Transactional` method from
  within the same class bypasses the proxy. Move the transactional method to
  a separate bean if needed.
- **Read‑only transactions** – Use `@Transactional(readOnly = true)` for
  query methods to allow Hibernate optimisations.

### Exception Handling
- Use **`@ControllerAdvice`** + `@ExceptionHandler` for a global error
  handling layer.
- Return a consistent error response body (e.g. `{ "error": "...", "message": "...", "timestamp": "..." }`).
- Map domain exceptions to HTTP status codes in the advice, not in controllers.

### Validation
- Use **Bean Validation** (`@NotNull`, `@Size`, `@Email`) on DTOs.
- Validate at the controller layer with `@Valid` (or `@Validated`).
- Do not duplicate validation logic in services.

---

## JPA / Hibernate

- **Prefer `@Query` with JPQL** over derived query methods when the query is
  non‑trivial. It makes the intent explicit.
- **Avoid `FetchType.EAGER`** – It often leads to N+1 problems. Use `LAZY`
  and fetch associations explicitly with `JOIN FETCH` or `@EntityGraph`.
- **Use `@BatchSize` or `@Fetch(FetchMode.SUBSELECT)`** to mitigate N+1 when
  lazy loading is unavoidable.
- **DTO projections** – Use interface‑based or constructor‑expression
  projections instead of returning full entities to the presentation layer.
- **`@Version` for optimistic locking** – Add a `@Version` field to entities
  that are updated concurrently.
- **Flyway / Liquibase for schema migration** – Never use `ddl-auto: update`
  in production.

---

## Testing

- **JUnit 5** – Use `@Test`, `@DisplayName`, `@Nested` for structured tests.
- **Mockito** – Mock external dependencies. Prefer `@ExtendWith(MockitoExtension.class)`.
- **AssertJ** for fluent assertions – `assertThat(result).isNotNull().hasFieldOrPropertyWithValue("name", "John")`.
- **Testcontainers** for integration tests that need a real database or
  message broker.
- **`@WebMvcTest`** for controller slice tests, **`@DataJpaTest`** for
  repository slice tests.
- **Test the behaviour, not the implementation** – Avoid mocking Spring
  internals. Test through public APIs.

---

## Security (Spring Security)

- **Use method security** (`@PreAuthorize`, `@PostAuthorize`) for fine‑grained
  access control in the service layer.
- **Never hard‑code secrets** – Use `application.yml` with placeholder values
  resolved from environment variables or a vault.
- **Enable CSRF protection** for state‑changing endpoints unless the API is
  stateless (e.g. JWT‑based).
- **Use BCrypt or Argon2** for password hashing. Never store plain‑text
  passwords.

---

## Production Patterns

- **Actuator** – Expose health, metrics, and info endpoints. Secure them
  behind a separate port or authentication.
- **Structured logging** – Use Logback with a JSON encoder. Include a
  correlation ID (trace ID) in every log line.
- **Micrometer for metrics** – Export to Prometheus, Datadog, or CloudWatch.
- **Graceful shutdown** – Enable `server.shutdown=graceful` and set a
  reasonable timeout.
- **Health checks** – Implement custom `HealthIndicator`s for critical
  external dependencies.

---

## Package Structure

Follow the **package‑by‑feature** convention:

```
com.example.order
├── Order.java              (entity)
├── OrderRepository.java
├── OrderService.java
├── OrderController.java
├── OrderDto.java
└── OrderMapper.java
```

Avoid splitting by technical layer (`controllers`, `services`, `repositories`)
across the whole codebase – it scatters related code and makes navigation harder.

---

## How to Use This Reference

1. Apply `code-excellence` first to establish the design philosophy.
2. Use this reference for concrete Java / Spring Boot implementation details.
3. When in doubt, consult the official Spring Boot reference documentation
   and "Effective Java" by Joshua Bloch.
