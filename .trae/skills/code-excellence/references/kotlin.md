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
- **Critical**: Only constructor properties are included in `equals`/`hashCode`. Body properties are ignored.
- Do **not** use for JPA `@Entity`. Use regular classes (see JPA section below).
- Prefer `copy()` for immutable updates over mutable setters.

### Null Safety — Expert Patterns
```kotlin
// Safe call + Elvis for early exit
val name = user?.name ?: return
val config = settings.timeout ?: throw IllegalStateException("timeout required")

// Elvis with `also` for side effects on null
val cache = cacheMap[key] ?: run {
    val fresh = loadFromDb(key)
    cacheMap[key] = fresh
    fresh
}

// !! — use ONLY when:
// 1. You've already checked for null (defensive re-check)
// 2. It's a precondition violation (fail fast)
// NEVER use !! for expected nulls — that's what `?:` is for
val user: User = findUser(id) ?: throw UserNotFoundException(id)
```

**Platform types from Java are dangerous**: `user.name` where `user` is from Java could be null at runtime. Always annotate Java interop with `@Nullable`/`@NonNull` or add explicit null checks.

### Sealed Classes & when
```kotlin
sealed interface OrderState {
    data class Pending(val orderId: Long) : OrderState
    data class Confirmed(val orderId: Long, val paymentId: String) : OrderState
    data class Cancelled(val orderId: Long, val reason: String) : OrderState
}

// Exhaustive — compiler errors if you miss a branch
val status = when (state) {
    is OrderState.Pending -> "awaiting payment"
    is OrderState.Confirmed -> "confirmed, paying ${state.paymentId}"
    is OrderState.Cancelled -> "cancelled: ${state.reason}"
}
```

### Scope Functions — Correct Usage
```kotlin
// let: transform nullable, null-safe
user?.let { repo.save(it) }

// apply: configure object, return self
val config = AppConfig().apply {
    timeout = 30.seconds
    retries = 3
}

// also: side effects on object, return self
db.connect().also { logger.info("Connected to {}", it.url) }

// run: compute result from context
val result = obj.run { computeSomething() }

// with: compute from non-null receiver
with(formatter) { format(user) }
```
**Rule**: Never nest scope functions past 2 levels. If you need `obj.let { it.field.apply { ... } }`, extract to a named function.

---

## Collections — Safety Patterns

```kotlin
// first() throws on empty — use firstOrNull() when uncertain
val admin = users.first { it.isAdmin }        // NoSuchElementException if none
val admin = users.firstOrNull { it.isAdmin }  // null if none — SAFE

// last() throws — use lastOrNull()
val last = orders.last { it.isActive }        // throws if none match

// single() throws if 0 or >1 match — use singleOrNull()
val config = configs.single { it.isDefault }  // throws if missing or duplicate

// elementAt() throws on out-of-bounds — use getOrNull() or elementAtOrNull()
val third = list.elementAt(2)                 // throws if size < 3

// filter vs filterTo — avoid intermediate collections for large datasets
val actives = users.asSequence().filter { it.isActive }.toList()
```

---

## Extension Functions — Limitations

```kotlin
// Extensions are resolved STATICALLY — not polymorphic
open class Animal
class Dog : Animal()

fun Animal.speak() = "generic"
fun Dog.speak() = "woof"

val a: Animal = Dog()
a.speak() // "generic" — NOT "woof"! Resolved by declared type, not runtime type
```

**Rule**: Extensions are compile-time syntactic sugar. They do NOT override. Use them for utility operations, not for polymorphic behavior.

**SAM conversion**: Only Java interfaces get SAM conversion. For Kotlin interfaces, use `fun interface`.

```kotlin
// Java interface — SAM works
val runnable = Runnable { println("running") }

// Kotlin interface — needs fun interface
fun interface KotlinCallback { fun call() }
val callback = KotlinCallback { println("called") }
```

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

// INJECT dispatchers for testability — don't hardcode
class UserService(
    private val ioDispatcher: CoroutineDispatcher = Dispatchers.IO
) {
    suspend fun find(id: Long) = withContext(ioDispatcher) { repo.findById(id) }
}
// In tests: UserService(testDispatcher) for deterministic execution
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
- Use `StateFlow` for observable state — needs initial value and never completes.
- Use `SharedFlow` for one-shot events (no initial value, can have multiple subscribers).

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

## Delegation Patterns

### Class Delegation
```kotlin
interface Printer { fun print(doc: Document) }
class RealPrinter : Printer { override fun print(doc: Document) { ... } }

class LoggingPrinter(private val delegate: Printer) : Printer by delegate {
    override fun print(doc: Document) {
        log.info("Printing: ${doc.name}")
        delegate.print(doc)
    }
}
```

### Property Delegation
```kotlin
// Lazy initialization — thread-safe by default
val config by lazy { ConfigLoader.load() }

// Observable properties
var status by Delegates.observable("init") { prop, old, new ->
    log.info("$prop changed from $old to $new")
}

// Map-backed properties — useful for DTOs from JSON
class User(val map: Map<String, Any>) {
    val name: String by map
    val age: Int by map
}
```

---

## Kotlin + JPA Specifics

### Entity Definition
```kotlin
@Entity
class Order(
    @Id @GeneratedValue var id: Long = 0,
    var status: String = "",
    @OneToMany(mappedBy = "order", fetch = FetchType.LAZY)
    var items: MutableList<OrderItem> = mutableListOf()
) {
    // Regular class, NOT data class. Override equals/hashCode on @Id.
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is Order) return false
        return id != 0L && id == other.id
    }
    override fun hashCode(): Int = if (id != 0L) id.hashCode() else System.identityHashCode(this)

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

## Java Interop — Critical Rules

| Kotlin | Java Equivalent | Note |
|--------|----------------|------|
| `==` | `equals()` | Structural equality in Kotlin |
| `===` | `==` | Reference equality in Kotlin (opposite of Java) |
| `fun interface` | Java SAM | Kotlin interfaces need `fun` for SAM |
| `@JvmStatic` | static method | For companion object methods |
| `@JvmOverloads` | overloaded methods | Generates Java-friendly overloads for default params |
| `@JvmField` | public field | Exposes property as field (no getter) |

```kotlin
// Companion object with Java-friendly static access
class Config {
    companion object {
        @JvmStatic
        fun default(): Config = Config()
    }
}
// Java: Config.default()
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
