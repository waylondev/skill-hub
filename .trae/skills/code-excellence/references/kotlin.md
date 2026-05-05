# Kotlin Best Practices

## Purpose

This reference encodes **Kotlin‑specific** best practices that, combined with
the parent `code-excellence` skill, guide AI to produce production‑grade,
idiomatic Kotlin code. For Spring Boot framework guidance, see `springboot.md`.

---

## Kotlin Language Idioms

### Data Classes for DTOs & Value Objects
```kotlin
data class User(val id: Long, val name: String)
```
- Auto‑generates `equals`, `hashCode`, `toString`, and `copy`.
- Do **not** use data classes for JPA entities — Hibernate proxies break `equals`/`hashCode`. Use regular classes and override `equals`/`hashCode` based on `@Id`.

### val over var
- Prefer immutability. Use `var` only when mutation is unavoidable.
- `val` means read‑only reference, not deeply immutable — but it signals intent.

### Null Safety
```kotlin
val length = name?.length ?: 0              // safe call + elvis
user!!.address                               // avoid unless absolutely certain
```
- Use `?.`, `?:`, and `let` for null‑safe chains. Avoid `!!` — it crashes where a proper error would serve better.
- Never return `null` from a function that should always produce a value. Use `sealed class Result<T>` instead.

### Extension Functions
```kotlin
fun String.isValidEmail(): Boolean = this.contains("@") && this.contains(".")
```
- Add behaviour to existing types without inheritance.
- Keep extension functions focused and discoverable. Don't abuse them to hide complexity.

### Sealed Classes & Interfaces
```kotlin
sealed class Result<out T> {
    data class Success<T>(val data: T) : Result<T>()
    data class Error(val message: String) : Result<Nothing>()
}
```
- Model restricted hierarchies. Combined with exhaustive `when`, guarantees all cases handled at compile time.

### when Expression
```kotlin
val description = when (result) {
    is Result.Success -> "Got: ${result.data}"
    is Result.Error -> "Failed: ${result.message}"
}
```
- Exhaustive `when` with sealed classes forces handling of every branch.
- No `else` needed when all branches are covered — future additions cause compile errors.

### Scope Functions
```kotlin
user?.let { saveToDatabase(it) }            // null‑safe transformation
val config = AppConfig().apply { ... }      // initialise and return self
```
- `let` — transform a nullable. `apply` — configure an object. `run` / `with` — compute a result.
- Avoid deep nesting. If scope functions create a pyramid, extract named functions.

### Collections API
```kotlin
val names = users.filter { it.isActive }.map { it.name }
val grouped = users.groupBy { it.department }
```
- Use sequences (`asSequence()`) for large, multi‑step transformations to avoid intermediate collections.

### Coroutines
```kotlin
suspend fun fetchUser(id: Long): User = withContext(Dispatchers.IO) { ... }

// Structured concurrency
coroutineScope {
    val user = async { fetchUser(1) }
    val order = async { fetchOrders(1) }
    UserWithOrders(user.await(), order.await())
}
```
- Use `suspend` functions for async, non‑blocking code.
- **Never use `GlobalScope`**. Use `coroutineScope` or `supervisorScope` for structured concurrency.
- `runBlocking` only at the application boundary (tests, `main`).
- Use `Dispatchers.IO` for blocking I/O, `Dispatchers.Default` for CPU‑intensive work.

---

## Testing

- **Kotest** — Kotlin‑native testing with `StringSpec`, `ShouldSpec`, `DescribeSpec`. Or stick with **JUnit 5**.
- **MockK** — `mockk<T>()`, `every { ... } returns ...`, `verify { ... }`. Supports coroutines, extension functions, and object mocking natively.
- **Test behaviour, not implementation** — test through public APIs, not internal `private` functions.

---

## How to Use This Reference

1. Apply `code-excellence` first for universal design principles.
2. Use this reference for Kotlin‑specific idioms and syntax choices.
3. If using Spring Boot, also consult `springboot.md`.
4. For deeper understanding, refer to "Kotlin in Action" and the official Kotlin documentation.
