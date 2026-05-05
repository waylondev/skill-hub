# Python Best Practices (3.12+)

## Purpose

This reference encodes **Python‑specific** best practices that, combined with
the parent `code-excellence` skill, guide AI to produce production‑grade,
idiomatic Python code.

---

## Python Language Idioms (3.12+)

- **Follow PEP 8** — 4 spaces for indentation, `snake_case` for functions and variables, `PascalCase` for classes.
- **`dataclasses` for data containers** — `@dataclass(frozen=True) class Point: x: int; y: int` reduces boilerplate and guarantees immutability.
- **Type hints everywhere** — annotate function signatures, return types, and complex variables. Run `mypy` or `pyright` in CI with strict mode.
- **New type syntax (3.12+)** — `list[int]`, `dict[str, User]`, `tuple[int, ...]` without importing from `typing`.
- **`Self` type (3.11+)** — `def clone(self) -> Self: ...` for fluent APIs and factory methods.
- **`@override` (3.12+)** — explicitly declare method overrides. IDE warns if the base method changes or is removed.
- **`match` / `case` (3.10+)** — structural pattern matching for dispatching on complex shapes.
- **`pathlib`** — `Path("data") / "file.txt"` is cleaner and cross‑platform. Never use `os.path`.
- **`f-strings`** — `f"User {name} has {count} items"` is concise, fast, and supports `=` debugging: `f"{count=}"`.
- **Context managers (`with`)** — for files, locks, DB connections. Write custom ones with `contextlib.contextmanager` or `__enter__`/`__exit__`.

---

## Python 3.11+ Features

- **`tomllib`** — built‑in TOML parser, no third‑party dependency needed to read `pyproject.toml`.
- **`ExceptionGroup` / `except*`** — aggregate multiple concurrent exceptions and handle them structurally.
- **`LiteralString`** — type that only accepts literal strings, preventing SQL injection in type‑checked query builders.
- **`TaskGroup`** (3.11+) — structured async concurrency, better than raw `asyncio.gather` with `return_exceptions=True`.

---

## Project Structure

```
├── src/
│   └── mypackage/
│       ├── __init__.py
│       ├── core.py
│       ├── services.py
│       └── models.py
├── tests/
│   ├── __init__.py
│   ├── test_core.py
│   └── conftest.py
├── pyproject.toml
├── README.md
└── .env.example
```

- **`pyproject.toml`** — the single source of truth for dependencies, build configuration, tool settings (`[tool.pytest]`, `[tool.mypy]`, `[tool.ruff]`).
- **Define entry points**:
```toml
[project.scripts]
mycli = "mypackage.cli:main"
```
- **Virtual environments** — use `uv` or `venv`. Never install dependencies globally.
- **Lock file** — commit `uv.lock` or `requirements/*.txt` with pinned versions.

---

## Async / Await

- `async def` / `await` for I/O‑bound work — network calls, DB queries, file I/O.
- `asyncio.gather` for concurrent tasks. Use `TaskGroup` (3.11+) for structured concurrency.
- **Never mix sync and async** — don't call `asyncio.run()` inside an async function. Keep the boundary at the application entry point.
- **`httpx` for async HTTP** — supports both sync and async clients with a unified API.
- **ASGI** (`uvicorn` + FastAPI/Starlette) for production async web apps.

---

## Error Handling

- **Catch specific exceptions** — never bare `except:`. Catch `ValueError`, `KeyError`, `OSError`.
- **Exception chaining** — `raise ValueError("Invalid ID") from original_exception` preserves the traceback chain.
- **Custom exceptions** — subclass `Exception` for business errors. Keep the hierarchy shallow.
- Use `try` / `except` / `else` / `finally` — `else` runs only when no exception occurred.

---

## Testing

- **`pytest`** — the standard. Fixtures in `conftest.py` for shared setup.
- **`@pytest.mark.parametrize`** for table‑driven tests.
- **`pytest-cov`** for coverage reports.
- **`unittest.mock`** or `pytest-mock` for mocking external dependencies.
- **Test behaviour, not implementation** — through public APIs. Avoid mocking internal helper functions.

---

## Production Patterns

- **Structured logging** — `structlog` emits JSON logs with correlation IDs.
- **Configuration** — `pydantic-settings` loads environment variables into typed, validated models.
- **Health checks** — `/health` (FastAPI / Flask). Include readiness checks for critical external services.
- **Graceful shutdown** — handle `SIGTERM`, drain in‑flight requests.
- **`uv` as package manager** — faster than pip, with lockfile support.

---

## Web Frameworks

| Framework | When to use |
|-----------|-------------|
| **FastAPI** | New APIs. Async native, auto OpenAPI docs, leverages type hints for validation & serialisation. Preferred for new projects. |
| **Django** | Full‑featured applications needing admin, ORM, auth, and batteries. Follow the Django way (fat models, thin views). |
| **Flask** | Small services or maximum control. Use Blueprints for modularity. |

---

## How to Use This Reference

1. Apply `code-excellence` first.
2. Use this reference for Python‑specific idioms and project choices.
3. Refer to "Effective Python" (Brett Slatkin, 3rd edition) and PEP 8 for deeper understanding.
