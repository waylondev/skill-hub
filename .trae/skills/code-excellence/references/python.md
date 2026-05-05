# Python Best Practices (3.12+) — Expert Level

## Purpose

This reference encodes **Python‑specific expert practices** that, combined with
the parent `code-excellence` skill and its pattern catalog, guide AI to produce
production‑grade, idiomatic Python code.

---

## Python Language Idioms (3.12+)

- **PEP 8** — 4 spaces, `snake_case`, `PascalCase`.
- **dataclasses** — `@dataclass(frozen=True)` for immutable data carriers.
- **Type hints everywhere** — `mypy`/`pyright` strict mode in CI.
- **New type syntax (3.12+)** — `list[int]`, `dict[str, User]` directly, no `typing` import.
- **Self type (3.11+)** — `def clone(self) -> Self: ...`
- **@override (3.12+)** — explicit override declarations.
- **match/case** — structural pattern matching.
- **pathlib** — never `os.path`. `Path("data") / "file.txt"`.
- **f-strings** — `f"User {name} has {count} items"`. Debug: `f"{count=}"` → `count=42`.
- **Context managers** — `with` for files, locks, DB connections.

---

## Performance & Memory Expertise

### The GIL Reality
- CPython's GIL prevents true parallel CPU execution. Multi‑threading helps ONLY for I/O‑bound work.
- For CPU‑bound parallelism, use `multiprocessing` or `concurrent.futures.ProcessPoolExecutor`.
- Python 3.13+ introduces experimental `--disable-gil` builds. Check `sys._is_gil_enabled()`.

### Memory Patterns
```python
# Generators over lists — especially for large data
def read_logs(path: Path):
    with open(path) as f:
        for line in f:          # lazy iteration, one line in memory at a time
            yield parse(line)

# slots reduce per‑instance memory
class Point:
    __slots__ = ('x', 'y')      # no __dict__, ~50% memory savings
    def __init__(self, x: float, y: float): ...
```

### Profiling
```bash
python -m cProfile -s cumtime script.py     # function-level profiling
py-spy top -- python script.py              # live sampling profiler
memray run script.py                         # memory allocation profiler
```

---

## Async/Await — Expert Patterns

### Structured Concurrency with TaskGroup (3.11+)
```python
async with asyncio.TaskGroup() as tg:
    user_task = tg.create_task(fetch_user(1))
    order_task = tg.create_task(fetch_orders(1))
# If either fails, the other is cancelled automatically.
result = UserWithOrders(user_task.result(), order_task.result())
```

### Semaphore for Rate Limiting
```python
sem = asyncio.Semaphore(10)  # max 10 concurrent
async with sem:
    await call_external_api(url)
```

---

## Pydantic v2 — Data Validation

```python
from pydantic import BaseModel, Field, field_validator

class CreateOrderRequest(BaseModel):
    model_config = {"extra": "forbid"}  # reject unknown fields
    user_id: int = Field(gt=0)
    items: list[OrderItem]
    total: Decimal = Field(max_digits=10, decimal_places=2)

    @field_validator("items")
    @classmethod
    def not_empty(cls, v): assert len(v) > 0; return v
```

---

## Testing — Expert Level

### pytest with fixtures and parametrize
```python
@pytest.fixture
def sample_order(): return Order(id=1, items=[Item(price=100)])

@pytest.mark.parametrize("quantity,expected", [(1, 100), (5, 450), (10, 800)])
def test_bulk_discount(sample_order, quantity, expected):
    assert calculate(sample_order, quantity) == expected
```

### Property-based Testing (Hypothesis)
```python
from hypothesis import given, strategies as st

@given(st.lists(st.integers(min_value=1, max_value=1000), min_size=1))
def test_sum_is_positive(items):
    assert sum(items) > 0
# Generates hundreds of random lists automatically
```

### Timezone‑Safe Testing
```python
import zoneinfo
# Never use datetime.now() without tz. Always:
now = datetime.now(tz=zoneinfo.ZoneInfo("UTC"))
```

---

## Production Patterns

### FastAPI with Dependency Injection
```python
async def get_db():  # dependency
    async with AsyncSessionLocal() as session:
        yield session

@router.get("/orders/{id}")
async def get_order(id: int, db=Depends(get_db)):
    return (await db.get(Order, id)).to_dto()
```

### Structured Logging
```python
import structlog
logger = structlog.get_logger()
logger.info("order.created", order_id=id, amount=total, trace_id=trace_id)
```

### Configuration with pydantic-settings
```python
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    database_url: str
    redis_url: str
    api_key: str

settings = Settings()  # reads from env vars automatically
```

---

## How to Use This Reference

1. Apply `code-excellence` SKILL.md for the operation pipeline.
2. Consult `decision-trees.md` for design choices.
3. Use this reference for Python‑specific expert implementation.
4. For deeper dives: "Effective Python" (Slatkin, 3rd edition), "Fluent Python" (Ramalho, 2nd edition).
