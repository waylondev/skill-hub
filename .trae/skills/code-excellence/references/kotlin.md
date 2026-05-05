# Kotlin Best Practices — Expert Level

## Purpose

This reference encodes **Kotlin‑specific expert practices** that, combined with
the parent `code-excellence` skill and its pattern catalog, guide AI to produce
production‑grade, idiomatic Kotlin code. For Spring Boot framework guidance, see `springboot.md`.

---

## Kotlin Language Idioms

### Data Classes
```kotlin
data class User(val id: Long, val name: String)
```
- `equals`, `hashCode`, `toString`, `copy` — auto‑generated.
- Do **not** use for JPA `@Entity`. Use regular classes and override `equals`/`hashCode` based on `@Id`.

### Null Safety
```kotlin
val length = name?.length ?: 0
user?.let { saveToDatabase(it) }
// user!!.address — avoid. Crashes with NPE instead of a proper error.
```

### Sealed Classes & when
```kotlin
sealed class Result<out T> {
    data class Success<T>(val data: T) : Result<T>()
    data class Error(val message: String) : Result<Nothing>()
}

val description = when (result) {
    is Result.Success -> "Got: ${result.data}"
    is Result.Error   -> "Failed: ${result.message}"
} // Exhaustive: adding a variant → compile error in every when
```

### Scope Functions
```kotlin
user?.let { repo.save(it) }           // null‑safe transform
val config = AppConfig().apply { ... } // configure and return self
val result = obj.run { compute() }     // compute from context
```
- `let` = transform, `apply` = configure, `run`/`with` = compute.
- Avoid deep nesting. Extract named functions past 2 levels.

---

## Coroutines — Expert Depth

### Structured Concurrency
```kotlin
suspend fun loadUserWithOrders(id: Long) = coroutineScope {
    val user = async { userRepo.findById(id) }
    val orders = async { orderRepo.findByUserId(id) }
    UserWithOrders(user.await(), orders.await())
}
// If either async fails, coroutineScope cancels the other automatically.
// No orphaned coroutines. No leaked resources.
```

### Dispatcher Selection
```kotlin
withContext(Dispatchers.IO) { ... }       // Blocking I/O (DB, files, network)
withContext(Dispatchers.Default) { ... }  // CPU‑intensive work
// NEVER: GlobalScope.launch — uncontrolled lifecycle, impossible to cancel
// NEVER: runBlocking inside a suspend function — blocks the thread
```

### SupervisorScope vs coroutineScope
```kotlin
// coroutineScope: one child fails → ALL siblings cancelled
// supervisorScope: one child fails → siblings continue
supervisorScope {
    val analytics = async { trackEvent(e) }   // failure here...
    val critical = async { processPayment(p) } // ...does NOT cancel this
}
```

### Flow for Reactive Streams
```kotlin
flow { emit(loadPage(1)); emit(loadPage(2)) }
    .flatMapMerge { page -> flow { emit(process(page)) } }
    .catch { e -> log.error("Pipeline failed", e) }
    .flowOn(Dispatchers.Default)
    .collect { ... }
```
- Use `SharedFlow` for multicasting events (replaces `BroadcastChannel`).
- Use `StateFlow` for observable state (replaces `LiveData` outside Android).

### Coroutine Testing
```kotlin
@Test
fun `loads user and orders concurrently`() = runTest {
    val result = service.loadUserWithOrders(1)
    assertEquals("Alice", result.user.name)
    assertEquals(3, result.orders.size)
    // runTest auto‑skips delays, controls virtual time
}
```

---

## K2 Compiler (Kotlin 2.0+)

- **K2 is the new default** in Kotlin 2.0+. 2x faster compilation, better type inference.
- **Migration**: Enable `kotlin.experimental.tryK2=true` in 1.9.x, go full K2 in 2.0.
- **Breaking change**: Some implicit type coercions that worked in K1 are errors in K2. Test before upgrading.

### data object (Kotlin 1.9+)
```kotlin
data object Idle : ConnectionState  // toString() returns "Idle" automatically
```

### entries (Kotlin 1.9+)
```kotlin
enum class Status { PENDING, ACTIVE, CLOSED }
Status.entries  // replaces Status.values() — returns a List, not an Array
```

---

## Inline (Value) Classes
```kotlin
@JvmInline
value class UserId(val value: Long)

fun findUser(id: UserId): User = ...
// At runtime: just a Long. Zero allocation overhead.
// Use for type‑safe IDs, Money, Email — any single‑field wrapper.
```

---

## Kotlin + JPA Specifics

### Entity Definition
```kotlin
@Entity
class Order(
    @Id @GeneratedValue var id: Long = 0,
    var status: String,
    @OneToMany(mappedBy = "order", fetch = LAZY)
    var items: MutableList<OrderItem> = mutableListOf()
) {
    // Regular class, NOT data class. Override equals/hashCode on @Id.
    override fun equals(other: Any?): Boolean = /* compare by id */
    override fun hashCode(): Int = id.hashCode()

    // Domain behavior lives here
    fun addItem(item: OrderItem) { items.add(item); item.order = this }
}
```

### Extensions for DTO Mapping
```kotlin
fun Order.toDto() = OrderDto(id = id, status = status,
    items = items.map { it.toDto() })
```

---

## Testing — Expert Tools

```kotlin
// Kotest — Kotlin-native testing
class OrderServiceTest : StringSpec({
    "should calculate total with discount" {
        val order = Order(items = listOf(Item(price = 100), Item(price = 200)))
        order.total shouldBe Money(270) // 10% discount applied
    }
})

// MockK — coroutine-aware mocking
val repo = mockk<OrderRepository>()
coEvery { repo.findById(1) } returns Order(id = 1)
coVerify { repo.findById(1) }
```

---

## How to Use This Reference

1. Apply `code-excellence` SKILL.md for the operation pipeline.
2. Consult `decision-trees.md` for design choices.
3. Use this reference for Kotlin‑specific implementation.
4. If using Spring Boot, also consult `springboot.md`.
5. For deeper dives: "Kotlin in Action", official Kotlin coroutines guide.
