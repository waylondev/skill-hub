# Production-Grade CRUD Patterns

## Purpose

90% of application code is CRUD (Create, Read, Update, Delete). This reference
encodes the **expert-level** implementation of CRUD operations — not "it works"
but "production-ready with proper validation, error handling, and pagination".

---

## Pattern: Complete CRUD Stack (Java + Spring Boot)

### 1. Controller Layer — Input validation, error mapping, pagination

```java
@RestController
@RequestMapping("/api/v1/orders")
@Validated
@RequiredArgsConstructor
public class OrderController {
    private final OrderService orderService;

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public OrderDto create(@Valid @RequestBody CreateOrderRequest request) {
        return orderService.create(request);
    }

    @GetMapping
    public Page<OrderDto> list(
            @RequestParam(defaultValue = "0") @Min(0) int page,
            @RequestParam(defaultValue = "20") @Min(1) @Max(100) int size,
            @RequestParam(required = false) OrderStatus status,
            @RequestParam(defaultValue = "createdAt") String sortBy,
            @RequestParam(defaultValue = "DESC") SortDirection direction
    ) {
        Sort sort = Sort.by(Direction.fromString(direction.name()), sortBy);
        return orderService.list(PageRequest.of(page, size, sort), status);
    }

    @GetMapping("/{id}")
    public OrderDto getById(@PathVariable Long id) {
        return orderService.findById(id)
            .orElseThrow(() -> new OrderNotFoundException(id));
    }

    @PutMapping("/{id}")
    public OrderDto update(@PathVariable Long id, @Valid @RequestBody UpdateOrderRequest request) {
        return orderService.update(id, request);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable Long id) {
        orderService.delete(id);
    }
}
```

### 2. Request DTOs — Validation constraints, clear error messages

```java
public record CreateOrderRequest(
    @NotNull(message = "userId is required")
    Long userId,

    @NotEmpty(message = "at least one item is required")
    @Size(min = 1, max = 100, message = "between 1 and 100 items allowed")
    List<OrderItemRequest> items,

    @NotBlank
    @Pattern(regexp = "^[A-Z]{3}$", message = "currency must be 3-letter ISO code")
    String currency
) {
    public record OrderItemRequest(
        @NotBlank String sku,
        @NotNull @Min(1) Integer quantity,
        @NotNull @Min(0) BigDecimal price
    ) {}
}
```

### 3. Response DTOs — Deliberate API contract, no entity leakage

```java
public record OrderDto(
    Long id,
    String status,
    String currency,
    MoneyDto total,
    List<OrderItemDto> items,
    Instant createdAt
) {}

public record MoneyDto(BigDecimal amount, String currency) {}

public record OrderItemDto(String sku, int quantity, MoneyDto unitPrice) {}
```

### 4. Global Error Handler — Consistent error response format

```java
@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(OrderNotFoundException.class)
    public ResponseEntity<ErrorResponse> notFound(OrderNotFoundException e) {
        return ResponseEntity.status(404).body(new ErrorResponse(
            "ORDER_NOT_FOUND", e.getMessage(), Instant.now()));
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ErrorResponse> validation(MethodArgumentNotValidException e) {
        String message = e.getBindingResult().getFieldErrors().stream()
            .map(fe -> fe.getField() + ": " + fe.getDefaultMessage())
            .collect(Collectors.joining(", "));
        return ResponseEntity.status(400).body(new ErrorResponse(
            "VALIDATION_ERROR", message, Instant.now()));
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ErrorResponse> unexpected(Exception e) {
        log.error("Unexpected error", e);
        return ResponseEntity.status(500).body(new ErrorResponse(
            "INTERNAL_ERROR", "An unexpected error occurred", Instant.now()));
    }

    public record ErrorResponse(String code, String message, Instant timestamp) {}
}
```

### 5. Service Layer — Transaction boundaries, business rules

```java
@Service
@RequiredArgsConstructor
public class OrderService {
    private final OrderRepository orderRepo;
    private final UserRepository userRepo;
    private final OrderMapper mapper;

    @Transactional
    public OrderDto create(CreateOrderRequest request) {
        // Validate user exists
        if (!userRepo.existsById(request.userId())) {
            throw new UserNotFoundException(request.userId());
        }

        // Build and save
        var order = mapper.toEntity(request);
        order.calculateTotal();
        var saved = orderRepo.save(order);

        // Return DTO
        return mapper.toDto(saved);
    }

    @Transactional(readOnly = true)
    public OrderDto findById(Long id) {
        return orderRepo.findDtoById(id); // projection query, not entity
    }

    @Transactional(readOnly = true)
    public Page<OrderDto> list(Pageable pageable, OrderStatus status) {
        return (status != null)
            ? orderRepo.findDtosByStatus(status, pageable)
            : orderRepo.findAllDtos(pageable);
    }
}
```

### 6. Repository Layer — Projection queries, pagination, no N+1

```java
public interface OrderRepository extends JpaRepository<Order, Long> {

    // Projection — only SELECT the columns the DTO needs
    @Query("SELECT new com.example.OrderDto(o.id, o.status, o.currency, " +
           "new com.example.MoneyDto(o.totalAmount, o.currency), " +
           "o.createdAt) " +
           "FROM Order o WHERE o.id = :id")
    Optional<OrderDto> findDtoById(@Param("id") Long id);

    @Query("SELECT new com.example.OrderDto(o.id, o.status, o.currency, " +
           "new com.example.MoneyDto(o.totalAmount, o.currency), " +
           "o.createdAt) " +
           "FROM Order o WHERE o.status = :status")
    Page<OrderDto> findDtosByStatus(@Param("status") OrderStatus status, Pageable pageable);

    Page<OrderDto> findAllDtos(Pageable pageable);
}
```

---

## Pattern: Complete CRUD Stack (Go + net/http)

```go
// handler/order.go
type OrderHandler struct {
    svc   OrderService
    log   *slog.Logger
}

func (h *OrderHandler) Create(w http.ResponseWriter, r *http.Request) {
    var req CreateOrderRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        respondError(w, http.StatusBadRequest, "INVALID_JSON", err.Error())
        return
    }
    if err := validateCreateOrder(&req); err != nil {
        respondError(w, http.StatusBadRequest, "VALIDATION_ERROR", err.Error())
        return
    }

    order, err := h.svc.Create(r.Context(), req)
    if err != nil {
        respondError(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Failed to create order")
        return
    }
    respondJSON(w, http.StatusCreated, order)
}

func (h *OrderHandler) Get(w http.ResponseWriter, r *http.Request) {
    id := r.PathValue("id")
    order, err := h.svc.GetByID(r.Context(), id)
    if err != nil {
        respondError(w, http.StatusNotFound, "ORDER_NOT_FOUND", "Order not found")
        return
    }
    respondJSON(w, http.StatusOK, order)
}

func (h *OrderHandler) List(w http.ResponseWriter, r *http.Request) {
    page, _ := strconv.Atoi(r.URL.Query().Get("page"))
    if page < 1 { page = 1 }
    size, _ := strconv.Atoi(r.URL.Query().Get("size"))
    if size < 1 || size > 100 { size = 20 }

    result, err := h.svc.List(r.Context(), page, size)
    if err != nil {
        respondError(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Failed to list orders")
        return
    }
    respondJSON(w, http.StatusOK, result)
}
```

---

## Pattern: Complete CRUD Stack (Python + FastAPI)

```python
from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field, field_validator
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

router = APIRouter(prefix="/orders", tags=["orders"])

# --- DTOs ---
class CreateOrderRequest(BaseModel):
    user_id: int = Field(gt=0)
    items: list[OrderItemRequest] = Field(min_length=1, max_length=100)

class OrderItemRequest(BaseModel):
    sku: str = Field(min_length=1)
    quantity: int = Field(gt=0)
    price: Decimal = Field(gt=0, max_digits=10, decimal_places=2)

class OrderResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    status: str
    total: Decimal
    created_at: datetime

# --- Routes ---
@router.post("", status_code=201, response_model=OrderResponse)
async def create_order(req: CreateOrderRequest, db: AsyncSession = Depends(get_db)):
    user = await db.get(User, req.user_id)
    if not user:
        raise HTTPException(404, "User not found")
    order = Order(user_id=req.user_id, items=[Item(**i.model_dump()) for i in req.items])
    order.calculate_total()
    db.add(order)
    await db.commit()
    await db.refresh(order)
    return order

@router.get("/{order_id}", response_model=OrderResponse)
async def get_order(order_id: int, db: AsyncSession = Depends(get_db)):
    order = await db.get(Order, order_id)
    if not order:
        raise HTTPException(404, "Order not found")
    return order

@router.get("", response_model=list[OrderResponse])
async def list_orders(
    page: int = Query(1, ge=1),
    size: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_db)
):
    offset = (page - 1) * size
    result = await db.execute(select(Order).offset(offset).limit(size))
    return result.scalars().all()
```

---

## CRUD Checklist

Every CRUD endpoint MUST satisfy:

- [ ] Input validation (required fields, ranges, formats)
- [ ] Output DTO (never entity/model directly)
- [ ] Error handling (400 for bad input, 404 for not-found, 500 for unexpected)
- [ ] Consistent error response format (`{ code, message, timestamp }`)
- [ ] Pagination on list endpoints (with max page size)
- [ ] Sorting whitelist (prevent SQL injection via sort param)
- [ ] Transaction boundaries on mutations
- [ ] 201 for CREATE, 204 for DELETE, 200 for READ/UPDATE
- [ ] Idempotency for critical POST operations (see patterns.md)
