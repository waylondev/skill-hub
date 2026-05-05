# Go Best Practices (1.22+)

## Purpose

This reference encodes **Go‑specific** best practices that, combined with
the parent `code-excellence` skill, guide AI to produce production‑grade,
idiomatic Go code.

---

## Go Language Idioms

- **Simplicity over cleverness** — Go values straightforward code. Avoid deep abstractions, heavy use of reflection, or complex generics unless they clearly reduce duplication.
- **Small interfaces** — The best Go interfaces have 1‑3 methods. Define interfaces where they are consumed, not where they are implemented.
- **Error handling** — Always check errors. Use `if err != nil { return fmt.Errorf("context: %w", err) }` to wrap errors with context. Never ignore errors with `_`.
- **`defer` for cleanup** — Use `defer` to close files, unlock mutexes, or cancel contexts. Deferred calls run in LIFO order.
- **Zero values are useful** — A `sync.Mutex` is ready without initialisation. A nil slice has `len` 0 and can be appended to.
- **Composition over inheritance** — Embed structs to reuse behaviour, not to create deep type hierarchies.
- **Avoid `panic` for expected errors** — Reserve `panic` for truly unrecoverable situations. Return errors for business logic failures.

---

## Go 1.22+ Key Changes

### Loop Variable Semantics
```go
// Go 1.22+: v is a fresh variable per iteration
for i, v := range items {
    go func() {
        process(v) // safe — v is no longer shared across iterations
    }()
}
```
- Before 1.22, closures captured the same loop variable — a classic footgun. Now fixed.

### Enhanced Routing in net/http
```go
mux := http.NewServeMux()
mux.HandleFunc("GET /users/{id}", handleGetUser)
mux.HandleFunc("POST /users", handleCreateUser)
```
- Method‑based routing and path parameters in the standard library. No third‑party router needed for moderate APIs.
- Extract path values with `r.PathValue("id")`.

---

## Project Layout

Follow the [golang-standards/project-layout](https://github.com/golang-standards/project-layout) conventions:

```
├── cmd/            # Main applications (one sub‑directory per binary)
├── internal/       # Private application code (not importable externally)
├── pkg/            # Library code safe for external use
├── api/            # API definitions (OpenAPI, protobuf)
├── configs/        # Configuration file templates
├── scripts/        # Build, install, analysis scripts
├── test/           # Additional external test apps and data
└── docs/           # Design documents
```

- **Keep `main.go` thin** — parse flags, initialise dependencies, start the server. Business logic in `internal/`.
- Use **`go.work`** for multi‑module local development:

```go
// go.work
go 1.22
use (
    ./backend/auth
    ./backend/orders
)
```

---

## Error Handling Patterns

- **Wrap errors with context** — `fmt.Errorf("failed to fetch user %d: %w", id, err)` preserves the original error for `errors.Is` / `errors.As`.
- **Sentinel errors** — `var ErrNotFound = errors.New("not found")` for well‑known error conditions.
- **Custom error types** — implement the `error` interface on a struct to carry additional metadata.
- **`errors.Is` / `errors.As`** — use them to check error identity and type, never `==` comparisons.
- **`errors.Join`** (Go 1.20+) — combine multiple errors into one.

---

## Concurrency

- **Goroutines are cheap, but not free** — spawn deliberately. Use a worker pool or `golang.org/x/sync/errgroup` for bounded parallelism.
- **Channels for communication** — "Do not communicate by sharing memory; share memory by communicating."
- **`context.Context`** — first parameter to functions doing I/O or long‑running work. Never store a `Context` in a struct.
- **`sync.WaitGroup`** — always pair `Add(1)` with `Done()`.
- **`select` for multiplexing** — always include `case <-ctx.Done():` for cancellation.
- **Avoid goroutine leaks** — every goroutine must have a way to exit.
- **`sync.OnceFunc` / `sync.OnceValue`** (Go 1.21+) — simplify single‑execution patterns without explicit `sync.Once`.

---

## Testing

- **Table‑driven tests** — a slice of test cases with name, input, expected output. Iterate with `t.Run(tt.name, func(t *testing.T) { ... })`.
- **`testify` for assertions** — `assert.Equal(t, expected, actual)` and `require.NoError(t, err)`.
- **`httptest` for HTTP handlers** — `httptest.NewServer` to test clients and handlers without real network calls.
- **`go test -race`** — always run the race detector in CI.
- **Benchmarks** — `func BenchmarkXxx(b *testing.B)`. Use `b.ResetTimer()` to exclude setup cost.
- **`testing/synctest`** (Go 1.24+ experimental) — deterministic testing of concurrent code.

---

## Dependency Management

- **Go Modules** — `go mod init`, `go mod tidy`. Commit `go.sum` to version control.
- **Keep dependencies minimal** — prefer the standard library. Add a third‑party dependency only when it provides significant value.
- **Pin versions** — use `go mod vendor` for reproducible builds.

---

## Production Patterns

- **Structured logging** — `log/slog` (Go 1.21+) emits JSON with structured key‑value pairs. Include a trace ID.
- **Metrics** — expose Prometheus metrics via `promhttp.Handler()`.
- **Health checks** — `/health` (liveness) and `/ready` (readiness) endpoints.
- **Graceful shutdown** — listen for `SIGINT`/`SIGTERM`, call `srv.Shutdown(ctx)` with a timeout.
- **Configuration** — environment variables or a config file (e.g. `viper`). Never hard‑code secrets.

---

## How to Use This Reference

1. Apply `code-excellence` first.
2. Use this reference for Go‑specific idioms and patterns.
3. Refer to "Effective Go" and "The Go Programming Language" for deeper understanding.
