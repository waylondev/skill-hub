# Python Best Practices

## Purpose

This reference encodes **Python‑specific** best practices that, combined with
the parent `code-excellence` skill, guide AI to produce production‑grade,
idiomatic Python code.

---

## Python Language Idioms (3.10+)

- **Follow PEP 8** – Use 4 spaces for indentation, `snake_case` for
  functions and variables, `PascalCase` for classes.
- **`dataclasses` for data containers** – `@dataclass class Point: x: int; y: int`
  reduces boilerplate. Use `frozen=True` for immutability.
- **Type hints everywhere** – Annotate function signatures and variables.
  Use `mypy` or `pyright` for static checking.
- **`match` / `case` (structural pattern matching)** – Use for
  dispatching on complex data shapes (Python 3.10+).
- **Walrus operator `:=`** – Use in `while` loops and comprehensions
  to avoid repeated computation, but don't overuse.
- **List / dict / set comprehensions** – Prefer over `map`/`filter` with
  `lambda`. Keep them simple; extract to a function if they span multiple
  lines.
- **`pathlib` over `os.path`** – `Path("data") / "file.txt"` is more
  readable and cross‑platform.
- **`f-strings` for formatting** – `f"Hello, {name}!"` is concise and
  fast.
- **Context managers (`with`)** – Use for files, locks, database
  connections. Write custom context managers with `contextlib.contextmanager`
  or `__enter__`/`__exit__`.

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

- Use **`pyproject.toml`** for project metadata, dependencies, and tool
  configuration (replaces `setup.py`, `setup.cfg`, `requirements.txt`).
- **Virtual environments** – Use `venv` or `poetry`. Never install
  dependencies globally.

---

## Async / Await

- **`async def` / `await` for I/O‑bound work** – Use `asyncio` for
  network calls, database queries, file I/O.
- **`asyncio.gather` for concurrent tasks** – Run multiple coroutines
  concurrently and collect results.
- **Avoid mixing sync and async** – Don't call `asyncio.run()` inside
  an async function. Keep the async boundary at the application entry
  point.
- **Use `httpx` for async HTTP** – It supports both sync and async
  clients with the same API.

---

## Error Handling

- **Catch specific exceptions** – Never use bare `except:`. Catch
  `ValueError`, `KeyError`, `IOError`, etc.
- **`try` / `except` / `else` / `finally`** – Use `else` for code that
  should run only if no exception occurred. Use `finally` for cleanup.
- **Raise exceptions with context** – `raise ValueError("Invalid ID") from original_exception`
  preserves the traceback chain.
- **Custom exceptions** – Subclass `Exception` for business errors.
  Keep the hierarchy shallow.

---

## Testing

- **`pytest`** – The de facto standard. Use fixtures (`conftest.py`) for
  shared setup.
- **`parametrize`** for table‑driven tests – `@pytest.mark.parametrize("input,expected", [...])`.
- **`pytest-cov`** for coverage reports.
- **`unittest.mock`** or `pytest-mock` for mocking.
- **Test behaviour, not implementation** – Avoid mocking internal
  functions. Test through public APIs.

---

## Production Patterns

- **Structured logging** – Use `structlog` or `python-json-logger`.
  Include a correlation ID.
- **Configuration** – Use `pydantic-settings` or `python-dotenv` to
  load environment variables into typed models.
- **Health checks** – Expose a `/health` endpoint (FastAPI / Flask).
- **Graceful shutdown** – Handle `SIGTERM` and drain in‑flight requests.
- **ASGI for async web apps** – Use `uvicorn` with FastAPI or Starlette.

---

## Web Frameworks (Brief)

- **FastAPI** – Preferred for new APIs. Leverages type hints for
  validation, serialisation, and documentation.
- **Django** – Use for full‑featured applications with admin, ORM, and
  batteries included. Follow the "Django way" (fat models, thin views).
- **Flask** – Suitable for small services or when you need maximum
  control. Use Blueprints for modularity.

---

## How to Use This Reference

1. Apply `code-excellence` first.
2. Use this reference for Python‑specific implementation details.
3. Refer to "Effective Python" by Brett Slatkin and PEP 8 for deeper
   understanding.
