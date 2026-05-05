# Spring Boot Best Practices (3.2+)

## Purpose

This reference encodes **Spring‑Boot‑3.2+** best practices applicable to both
Java and Kotlin projects. Apply `code-excellence` first, then your language
reference (`java.md` or `kotlin.md`), then this reference.

---

## Dependency Injection

- **Constructor injection only** — dependencies are explicit, support `final` / `val` fields, and simplify unit testing.
- In Java, with a single constructor, `@Autowired` is optional.
- In Kotlin, a single constructor is auto‑wired: `class OrderService(private val repo: OrderRepository)`.

```java
// Java
@Service
public class OrderService {
    private final OrderRepository repo;
    public OrderService(OrderRepository repo) { this.repo = repo; }
}
```

```kotlin
// Kotlin
@Service
class OrderService(private val repo: OrderRepository)
```

---

## Configuration

- **`@ConfigurationProperties`** over `@Value` — type‑safe, testable, and groups related config.

```java
@ConfigurationProperties(prefix = "app.payment")
public record PaymentProperties(String gateway, Duration timeout) {}
```

```kotlin
@ConfigurationProperties(prefix = "app.payment")
data class PaymentProperties(val gateway: String, val timeout: Duration)
```

- Enable with `@EnableConfigurationProperties(PaymentProperties.class)` or `@ConfigurationPropertiesScan`.

---

## Bean Declaration

- Prefer **Java / Kotlin configuration** (`@Configuration` + `@Bean`) over XML.
- Use `@ComponentScan` sparingly in large projects — explicit wiring is easier to debug.

---

## Transaction Management

- `@Transactional` on **service methods**, never on controllers or repositories.
- Be aware of **self‑invocation**: calling a `@Transactional` method from within the same class bypasses the proxy. Extract to a separate bean if needed.
- `@Transactional(readOnly = true)` on query methods for Hibernate optimisations.

---

## Virtual Threads (Java 21)

```yaml
# application.yml
spring:
  threads:
    virtual:
      enabled: true
```
- Spring Boot 3.2+ auto‑configures virtual threads for Tomcat, Jetty, `@Async`, and task executors.
- Best for I/O‑heavy workloads. Leave CPU‑bound tasks on platform threads.

---

## HTTP Clients

- **RestClient** (Spring Boot 3.2+) — modern, fluent synchronous HTTP client. Replaces `RestTemplate` for new code.

```java
var client = RestClient.create();
var result = client.get()
    .uri("https://api.example.com/users/{id}", id)
    .retrieve()
    .body(User.class);
```

- **`@HttpExchange`** (Spring 6+) — declarative HTTP interfaces:

```java
@HttpExchange("/users")
interface UserClient {
    @GetExchange("/{id}")
    User getById(@PathVariable Long id);
}
```

---

## Exception Handling

- Use **`@ControllerAdvice`** + `@ExceptionHandler` for a global error handling layer.
- Return a consistent error body:

```json
{ "error": "NOT_FOUND", "message": "User 42 not found", "timestamp": "2026-01-01T00:00:00Z" }
```

- Map domain exceptions to HTTP status codes in the advice layer, not in controllers.

---

## Validation

- **Bean Validation** annotations (`@NotNull`, `@Size`, `@Email`) on DTOs.
- Validate at the controller layer with `@Valid` (or `@Validated`):

```java
@PostMapping("/users")
public UserDto create(@Valid @RequestBody CreateUserRequest request) { ... }
```
- Do **not** duplicate validation logic in services — the controller layer is the boundary.

---

## JPA / Hibernate (6.x)

Spring Boot 3.x ships Hibernate 6.x. Key implications:

- **Prefer `@Query` with JPQL** over derived query methods for non‑trivial queries — intent is explicit.
- **Avoid `FetchType.EAGER`** — use `LAZY` and fetch associations explicitly with `JOIN FETCH` or `@EntityGraph`.
- **`@BatchSize` or `@Fetch(SUBSELECT)`** to mitigate N+1 when lazy loading is unavoidable.
- **DTO projections** — interface‑based or constructor‑expression projections. Never return full entities to the presentation layer.
- **`@Version` for optimistic locking** on concurrently‑updated entities.
- **Flyway / Liquibase for schema migration** — never use `ddl-auto: update` in production.

**Kotlin‑specific Hibernate notes**:
- Use **regular classes**, not data classes for `@Entity`. Data class `equals`/`hashCode` includes all properties, which breaks Hibernate proxies. Override `equals`/`hashCode` based on `@Id`.
- `lateinit var` for lazy‑loaded mandatory associations.

---

## Security (Spring Security 6.x)

- **Method security** — `@PreAuthorize`, `@PostAuthorize` in the service layer for fine‑grained access control.
- **Never hard‑code secrets** — `application.yml` placeholders resolved from environment variables or a vault.
- **CSRF protection** — enable for state‑changing endpoints. Disable only for truly stateless APIs (JWT).
- **BCrypt / Argon2** for password hashing. Never store plain‑text passwords.

---

## Testing

**Test slices** — prefer narrow, fast tests over heavy `@SpringBootTest`:
- `@WebMvcTest` — controller layer, MockMvc.
- `@DataJpaTest` — repository layer, auto‑configured in‑memory DB or Testcontainers.
- `@JsonTest`, `@RestClientTest` — serialisation / HTTP client in isolation.

**Tools**:
- **JUnit 5** with `@Nested` for structured test organisation.
- **AssertJ** (Java) / **Kotest assertions** (Kotlin) for fluent assertions.
- **Mockito** (Java) / **MockK** (Kotlin) for mocking.
- **Testcontainers** for integration tests requiring real infrastructure.

```java
@Testcontainers
@DataJpaTest
class OrderRepositoryTest {
    @Container
    static PostgreSQLContainer<?> db = new PostgreSQLContainer<>("postgres:16");
    // tests use real PostgreSQL
}
```

---

## Production Patterns

- **Actuator** — expose `/health`, `/metrics`, `/info`. Secure behind a separate port or authentication.
- **Structured logging** — Logback JSON encoder or Logstash encoder. Include `traceId` and `spanId` in every log line.
- **Micrometer** for metrics — export to Prometheus, Datadog, or CloudWatch.
- **Graceful shutdown** — `server.shutdown=graceful` with a reasonable timeout period.
- **Health checks** — custom `HealthIndicator` implementations for critical external dependencies.

---

## Package Structure

**Package‑by‑feature**, not by technical layer:

```
com.example.order
├── Order.java            (entity / domain)
├── OrderRepository.java
├── OrderService.java
├── OrderController.java
├── OrderDto.java
└── OrderMapper.java
```

Avoid top‑level `controllers/`, `services/`, `repositories/` directories — they scatter related code and hurt navigability as the project grows.

---

## How to Use This Reference

1. Apply `code-excellence` first.
2. Apply your language reference (`java.md` or `kotlin.md`).
3. Use this reference for Spring Boot specifics.
4. For deeper understanding, refer to the official Spring Boot 3.x reference documentation.
