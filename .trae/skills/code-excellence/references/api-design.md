# API Design — Expert Reference

## Purpose

This reference encodes API design patterns for REST, gRPC, and GraphQL. It covers versioning, pagination, error responses, idempotency, and contract-first development.

---

## REST API Design

### Resource Naming

```
✅ Resources are nouns, not verbs
✅ Collections are plural
✅ Nesting reflects ownership, not routing convenience

✅ GET    /users/{id}                    — Get user
✅ POST   /users                         — Create user
✅ PUT    /users/{id}                    — Replace user (full)
✅ PATCH  /users/{id}                    — Partial update
✅ DELETE /users/{id}                    — Delete user
✅ GET    /users/{id}/orders             — Get user's orders
✅ GET    /orders?status=pending&sort=-created_at — Filter and sort

❌ GET    /getUser/{id}                  — Verb in path
❌ GET    /users/getAll                  — Action as sub-resource
❌ POST   /createOrder                   — Verb as resource
❌ GET    /orders?userId=123             — Owner should be path, not query param
```

### HTTP Status Codes

| Code | Meaning | When to Use |
|------|---------|-------------|
| **200 OK** | Success | GET, PUT, PATCH returned data |
| **201 Created** | Resource created | POST created a resource (include Location header) |
| **202 Accepted** | Accepted for async processing | Long-running operation (include status endpoint) |
| **204 No Content** | Success, no body | DELETE completed |
| **400 Bad Request** | Client error | Validation failure, malformed input |
| **401 Unauthorized** | Authentication required | Missing/invalid auth token |
| **403 Forbidden** | Permission denied | Authenticated but not authorized |
| **404 Not Found** | Resource doesn't exist | ID not found, soft-deleted resource |
| **409 Conflict** | State conflict | Duplicate resource, optimistic lock failure |
| **422 Unprocessable Entity** | Semantic validation failure | Input syntactically valid but semantically wrong |
| **429 Too Many Requests** | Rate limited | Include Retry-After header |
| **500 Internal Server Error** | Server error | Unexpected failure |
| **503 Service Unavailable** | Dependency down | Circuit breaker open, maintenance |

### Error Response Format (RFC 7807 Problem Details)

```json
{
  "type": "https://api.example.com/errors/payment-failed",
  "title": "Payment Failed",
  "status": 402,
  "detail": "The payment was declined by the issuing bank",
  "instance": "/orders/ORD-12345/payment",
  "traceId": "abc-123-def-456",
  "timestamp": "2026-01-15T10:30:00Z",
  "errors": [
    {
      "field": "paymentMethod.cardNumber",
      "code": "CARD_DECLINED",
      "message": "Insufficient funds"
    }
  ]
}
```

```java
// Spring Boot implementation
@RestControllerAdvice
public class ApiErrorHandler {

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ProblemDetail> handleValidation(MethodArgumentNotValidException ex) {
        var errors = ex.getBindingResult().getFieldErrors().stream()
            .map(fe -> new FieldError(fe.getField(), fe.getCode(), fe.getDefaultMessage()))
            .toList();

        var problem = ProblemDetail.forStatusAndDetail(HttpStatus.BAD_REQUEST,
            "Request validation failed");
        problem.setProperty("traceId", MDC.get("traceId"));
        problem.setProperty("errors", errors);
        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(problem);
    }

    @ExceptionHandler(OrderNotFoundException.class)
    public ResponseEntity<ProblemDetail> handleNotFound(OrderNotFoundException ex) {
        var problem = ProblemDetail.forStatusAndDetail(HttpStatus.NOT_FOUND, ex.getMessage());
        problem.setProperty("orderId", ex.getOrderId());
        problem.setProperty("traceId", MDC.get("traceId"));
        return ResponseEntity.status(HttpStatus.NOT_FOUND).body(problem);
    }
}
```

### API Versioning

| Strategy | Pros | Cons | When to Use |
|----------|------|------|-------------|
| **URL Path** (`/v1/users`) | Simple, cacheable, explicit | Clutters URL | Public APIs, breaking changes |
| **Header** (`Accept: application/vnd.api.v2+json`) | Clean URL, flexible | Harder to debug, cache complexity | Internal APIs, non-breaking evolution |
| **Query Param** (`/users?api-version=2`) | Simple | Breaks caching, not RESTful | Temporary migrations |

**URL Path Versioning (Recommended)**:

```java
// v1 — original
@RestController
@RequestMapping("/api/v1/users")
public class UserControllerV1 {
    @GetMapping("/{id}")
    public UserV1Dto getUser(@PathVariable Long id) { ... }
}

// v2 — new field, backward compatible (includes v1 field)
@RestController
@RequestMapping("/api/v2/users")
public class UserControllerV2 {
    @GetMapping("/{id}")
    public UserV2Dto getUser(@PathVariable Long id) {
        var v1 = userRepo.findById(id).orElseThrow();
        // v2 includes v1 fields + new fields
        return UserV2Dto.from(v1);
    }
}
```

**Versioning Rules**:
- **Major version** (v1 → v2): Breaking change. New path. Support v1 for N-1.
- **Minor version** (v1.1 → v1.2): Non-breaking. Add optional fields, no removal.
- **Patch version** (v1.2.1): Bug fixes. No API contract change.
- **Deprecation**: Announce deprecation → set `Deprecation` + `Sunset` headers → remove after timeline.

```
Deprecation: true
Sunset: Sat, 01 Jan 2027 00:00:00 GMT
Link: </api/v2/users>; rel="successor-version"
```

### Pagination

| Strategy | Best For | Performance |
|----------|----------|-------------|
| **Offset/Limit** | Admin pages, jump-to-page | O(n) — slow for deep pages |
| **Cursor-Based** | Feeds, infinite scroll | O(1) — always fast |
| **Keyset** | Ordered datasets | O(1) index seek |

```java
// Offset pagination response
public record PagedResponse<T>(
    List<T> data,
    int page,
    int size,
    long totalElements,
    int totalPages
) {}

// Cursor pagination response
public record CursorResponse<T>(
    List<T> data,
    String nextCursor,
    String prevCursor,
    boolean hasNext
) {}
```

```sql
-- Cursor pagination — O(1) performance
SELECT * FROM orders
WHERE created_at < :cursor_value
ORDER BY created_at DESC
LIMIT 20;
-- vs Offset: SELECT * FROM orders ORDER BY created_at DESC LIMIT 20 OFFSET 10000 (scans 10020 rows)
```

### Idempotency

```
Idempotency is REQUIRED for:
- POST requests that create or modify resources
- Any operation that may be retried (network timeout, client retry)

Idempotency is NOT needed for:
- GET, HEAD, OPTIONS (naturally idempotent)
- PUT (full replacement — naturally idempotent)
- DELETE (naturally idempotent — second delete returns 404 or 204)
```

```
Client sends:
  POST /api/v1/orders
  Idempotency-Key: req-abc-123
  { "userId": 1, "items": [...] }

Server behavior:
  1. Check if key exists in idempotency store
  2. If exists → return cached response (same status code, same body)
  3. If not exists → process request, store response, return
  4. Key expires after 24 hours (TTL)
```

### Filtering and Sorting

```
✅ Consistent query parameter convention:
   GET /orders?status=pending&userId=123        — Filter
   GET /orders?sort=-created_at,name             — Sort (- = desc, no prefix = asc)
   GET /orders?fields=id,status,total            — Field selection (sparse response)
   GET /orders?expand=user,items                 — Eager load related resources

✅ Pagination:
   GET /orders?page=1&size=20                    — Offset
   GET /orders?cursor=eyJpZCI6MTAwfQ&limit=20    — Cursor

✅ Range queries:
   GET /orders?createdAt_gte=2026-01-01&createdAt_lte=2026-01-31
```

---

## gRPC API Design

### Service Definition

```protobuf
syntax = "proto3";
package orders.v1;

import "google/protobuf/timestamp.proto";
import "google/api/annotations.proto";

option java_package = "com.example.orders.v1";
option go_package = "github.com/example/orders/v1;ordersv1";

service OrderService {
  rpc CreateOrder(CreateOrderRequest) returns (Order) {}
  rpc GetOrder(GetOrderRequest) returns (Order) {}
  rpc ListOrders(ListOrdersRequest) returns (ListOrdersResponse) {}
  rpc StreamOrderEvents(StreamOrderEventsRequest) returns (stream OrderEvent) {}
}

message Order {
  string id = 1;
  string user_id = 2;
  OrderStatus status = 3;
  repeated OrderItem items = 4;
  Money total = 5;
  google.protobuf.Timestamp created_at = 6;
}

enum OrderStatus {
  ORDER_STATUS_UNSPECIFIED = 0;
  ORDER_STATUS_PENDING = 1;
  ORDER_STATUS_CONFIRMED = 2;
  ORDER_STATUS_SHIPPED = 3;
  ORDER_STATUS_DELIVERED = 4;
  ORDER_STATUS_CANCELLED = 5;
}

message Money {
  string amount = 1; // decimal string to avoid precision loss
  string currency = 2; // ISO 4217
}

message OrderItem {
  string product_id = 1;
  int32 quantity = 2;
  Money unit_price = 3;
}
```

### Error Handling

```protobuf
// Use google.rpc.Status for structured errors
import "google/rpc/status.proto";
import "google/rpc/code.proto";

// Client receives:
// google.rpc.Status {
//   code: NOT_FOUND (5)
//   message: "Order ORD-123 not found"
//   details: [
//     google.rpc.BadRequest { field_violations: [{ field: "order_id", description: "..." }] }
//   ]
// }
```

### When to Choose gRPC

| Signal | Choose gRPC | Choose REST |
|--------|------------|-------------|
| Performance | < 10ms latency, high throughput | Normal latency acceptable |
| Data format | Binary (Protobuf), strict schema | Human-readable (JSON) |
| Streaming | Bidirectional streaming needed | Request-response only |
| Browser support | gRPC-Web (limited) | Universal |
| Debugging | Requires tools (grpcurl, BloomRPC) | curl, browser |
| Ecosystem | Internal microservices | Public APIs, third-party |

---

## GraphQL API Design

### Schema Design

```graphql
type Query {
  order(id: ID!): Order
  orders(status: OrderStatus, userId: ID, limit: Int, cursor: String): OrderConnection!
  user(id: ID!): User
}

type Mutation {
  createOrder(input: CreateOrderInput!): CreateOrderPayload!
  cancelOrder(id: ID!, reason: String): CancelOrderPayload!
}

type Order {
  id: ID!
  status: OrderStatus!
  user: User!
  items: [OrderItem!]!
  total: Money!
  createdAt: DateTime!
}

type OrderConnection {
  edges: [OrderEdge!]!
  pageInfo: PageInfo!
  totalCount: Int!
}

type OrderEdge {
  node: Order!
  cursor: String!
}

type PageInfo {
  hasNextPage: Boolean!
  hasPreviousPage: Boolean!
  startCursor: String
  endCursor: String
}

input CreateOrderInput {
  userId: ID!
  items: [OrderItemInput!]!
  idempotencyKey: String!
}

type CreateOrderPayload {
  order: Order
  errors: [Error!]
}
```

### N+1 Prevention — DataLoader

```java
// DataLoader batches individual requests into a single batch query
@Component
public class UserOrderDataLoader implements BatchLoader<Long, Order> {
    private final OrderRepository orderRepo;

    @Override
    public CompletionStage<List<Order>> load(List<Long> userIds) {
        // Single query: SELECT * FROM orders WHERE user_id IN (?, ?, ?)
        return CompletableFuture.supplyAsync(
            () -> orderRepo.findByUserIdIn(userIds));
    }
}
```

### When to Choose GraphQL

| Signal | Choose GraphQL | Choose REST |
|--------|---------------|-------------|
| Client needs | Variable data shapes, over-fetching prevention | Fixed data shapes |
| Mobile | Bandwidth-constrained, needs specific fields | Bandwidth not critical |
| Multiple clients | Each needs different data slices | All need same data |
| Caching | Complex (requires normalized cache) | Simple (URL = cache key) |
| Learning curve | Steeper for consumers | Universal |

---

## API Contract-First Development

### OpenAPI/Swagger Specification

```yaml
openapi: "3.1.0"
info:
  title: Order API
  version: "1.0.0"
  description: Order management API for e-commerce platform

paths:
  /api/v1/orders:
    post:
      operationId: createOrder
      summary: Create a new order
      parameters:
        - name: Idempotency-Key
          in: header
          required: true
          schema: { type: string, format: uuid }
      requestBody:
        required: true
        content:
          application/json:
            schema: { $ref: "#/components/schemas/CreateOrderRequest" }
      responses:
        "201":
          description: Order created
          headers:
            Location:
              schema: { type: string, format: uri }
          content:
            application/json:
              schema: { $ref: "#/components/schemas/Order" }
        "400":
          description: Validation error
          content:
            application/problem+json:
              schema: { $ref: "#/components/schemas/ProblemDetail" }

components:
  schemas:
    CreateOrderRequest:
      type: object
      required: [userId, items]
      properties:
        userId: { type: string, format: uuid }
        items:
          type: array
          minItems: 1
          items: { $ref: "#/components/schemas/OrderItem" }
    Order:
      type: object
      properties:
        id: { type: string, format: uuid }
        status: { $ref: "#/components/schemas/OrderStatus" }
        total: { $ref: "#/components/schemas/Money" }
        createdAt: { type: string, format: date-time }
    OrderStatus:
      type: string
      enum: [PENDING, CONFIRMED, SHIPPED, DELIVERED, CANCELLED]
```

### Contract-First Code Generation

```bash
# Generate Java Spring server stubs
openapi-generator generate \
  -i api/order-api.yaml \
  -g spring \
  -o generated-servers/java \
  --additional-properties=interfaceOnly=true,useTags=true

# Generate TypeScript client
openapi-generator generate \
  -i api/order-api.yaml \
  -g typescript-axios \
  -o generated-clients/typescript
```

**Rule**: The OpenAPI spec is the **source of truth**. Code is generated from it, not the other way around. Any manual changes to generated code are lost on regeneration.

---

## API Security

### Authentication & Authorization

```
✅ API Key: Machine-to-machine, no user context
✅ JWT Bearer Token: User context, stateless validation
✅ OAuth 2.0: Delegated access, third-party integration
✅ mTLS: Service-to-service in zero-trust networks
```

### Rate Limiting Headers

```
X-RateLimit-Limit: 1000          — Requests per window
X-RateLimit-Remaining: 998       — Remaining requests
X-RateLimit-Reset: 1642694400    — Window reset timestamp (Unix epoch)
Retry-After: 60                  — Seconds to wait (on 429 response)
```

### CORS Configuration

```java
@Configuration
public class CorsConfig {
    @Bean
    public WebMvcCustomizer corsCustomizer() {
        return registry -> registry.addMapping("/api/**")
            .allowedOrigins("https://app.example.com")
            .allowedMethods("GET", "POST", "PUT", "PATCH", "DELETE")
            .allowedHeaders("*")
            .exposedHeaders("X-RateLimit-Remaining", "Location")
            .maxAge(3600);
    }
}
```

**CORS Rules**:
- Never use `allowedOrigins("*")` with `allowCredentials(true)` — security bypass
- Whitelist specific origins, not patterns
- Preflight caching (`maxAge`) reduces OPTIONS requests

---

## Quick API Checklist

### REST
- [ ] Resource names are nouns, plural for collections?
- [ ] HTTP methods used correctly (GET/POST/PUT/PATCH/DELETE)?
- [ ] Status codes appropriate and consistent?
- [ ] Error responses follow RFC 7807 Problem Details?
- [ ] Pagination applied to all list endpoints?
- [ ] Idempotency key required for POST mutations?
- [ ] Versioning strategy defined and documented?
- [ ] Rate limiting headers included?

### gRPC
- [ ] Message fields numbered sequentially (no gaps)?
- [ ] Enums have UNSPECIFIED = 0 as first value?
- [ ] Backward-compatible: never remove or rename fields?
- [ ] Timestamps use `google.protobuf.Timestamp`?
- [ ] Money amounts use string (not double) for precision?
- [ ] Streaming RPCs have proper cancellation handling?

### GraphQL
- [ ] Mutations return payload type (not bare object)?
- [ ] Pagination uses cursor-based Connection pattern?
- [ ] DataLoader implemented to prevent N+1 queries?
- [ ] Input types separate from output types?
- [ ] Authorization checked at resolver level, not just schema?

### General
- [ ] OpenAPI/Protobuf/GraphQL schema is the source of truth?
- [ ] Contract tests verify implementation matches spec?
- [ ] Deprecation policy documented with sunset timeline?
- [ ] Sensitive data excluded from responses and logs?
