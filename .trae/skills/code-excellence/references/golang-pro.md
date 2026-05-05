# Go Best Practices

## Purpose

This reference encodes **Go‑specific** best practices that, combined with
the parent `code-excellence` skill, guide AI to produce production‑grade,
idiomatic Go code.

---

## Go Language Idioms

- **Simplicity over cleverness** – Go values straightforward code. Avoid
  deep abstractions, heavy use of reflection, or complex generics unless
  they clearly reduce duplication.
- **Small interfaces** – The best Go interfaces have 1‑3 methods. Define
  interfaces where they are consumed, not where they are implemented.
- **Error handling** – Always check errors. Use `if err != nil { return fmt.Errorf("context: %w", err) }`
  to wrap errors with context. Never ignore errors with `_`.
- **`defer` for cleanup** – Use `defer` to close files, unlock mutexes,
  or cancel contexts. Deferred calls run in LIFO order.
- **Zero values are useful** – A `sync.Mutex` is ready to use without
  initialisation. A nil slice has `len` 0 and can be appended to.
- **Composition over inheritance** – Embed structs to reuse behaviour,
  not to create deep type hierarchies.
- **Avoid `panic` for expected errors** – Reserve `panic` for truly
  unrecoverable situations. Return errors for business logic failures.

---

## Project Layout

Follow the [golang-standards/project-layout](https://github.com/golang-standards/project-layout)
conventions:

```
├── cmd/            # Main applications (one sub‑directory per binary)
├── internal/       # Private application code (not importable externally)
├── pkg/            # Library code that is safe for external use
├── api/            # API definitions (OpenAPI, protobuf)
├── configs/        # Configuration file templates
├── scripts/        # Build, install, analysis scripts
├── test/           # Additional external test apps and data
└── docs/           # Design documents
```

- **Keep `main.go` thin** – It should parse flags, initialise dependencies,
  and start the server. Business logic belongs in `internal/`.

---

## Error Handling Patterns

- **Wrap errors with context** – `fmt.Errorf("failed to fetch user %d: %w", id, err)`
  preserves the original error for `errors.Is` / `errors.As`.
- **Sentinel errors** – `var ErrNotFound = errors.New("not found")` for
  well‑known error conditions.
- **Custom error types** – Implement the `error` interface on a struct
  when you need to carry additional metadata.
- **`errors.Is` and `errors.As`** – Use them to check error types, not
  `==` comparisons.

---

## Concurrency

- **Goroutines are cheap, but not free** – Spawn them deliberately. Use
  a worker pool or `errgroup` for bounded parallelism.
- **Channels for communication, not just synchronisation** – "Do not
  communicate by sharing memory; share memory by communicating."
- **`context.Context` for cancellation and deadlines** – Pass `ctx` as
  the first parameter to functions that do I/O or long‑running work.
  Never store a `Context` in a struct.
- **`sync.WaitGroup` for waiting on goroutines** – Always pair `Add(1)`
  with `Done()`.
- **`select` for multiplexing** – Use `select` to wait on multiple
  channels. Always include a `case <-ctx.Done():` for cancellation.
- **Avoid goroutine leaks** – Ensure every goroutine has a way to exit.

---

## Testing

- **Table‑driven tests** – Use a slice of test cases with a name, input,
  and expected output. Iterate with `t.Run(tt.name, func(t *testing.T) { ... })`.
- **`testify` for assertions** – `assert.Equal(t, expected, actual)` and
  `require.NoError(t, err)` make tests readable.
- **`httptest` for HTTP handlers** – Use `httptest.NewServer` to test
  HTTP clients and handlers without real network calls.
- **`go test -race`** – Always run the race detector in CI.
- **Benchmarks** – Write `func BenchmarkXxx(b *testing.B)` functions.
  Use `b.ResetTimer()` to exclude setup cost.

---

## Dependency Management

- **Go Modules** – Use `go mod init`, `go mod tidy`, and `go mod vendor`
  for reproducible builds.
- **Keep dependencies minimal** – Prefer the standard library. Add a
  third‑party dependency only when it provides significant value.
- **Pin versions** – Commit `go.sum` to version control.

---

## Production Patterns

- **Structured logging** – Use `slog` (Go 1.21+) or `zerolog`/`zap`.
  Emit JSON logs with a trace ID.
- **Metrics** – Expose Prometheus metrics via `promhttp.Handler()`.
- **Health checks** – Provide `/health` and `/ready` endpoints.
- **Graceful shutdown** – Listen for `SIGINT`/`SIGTERM`, call `srv.Shutdown(ctx)`
  with a timeout.
- **Configuration** – Use environment variables or a configuration file
  (e.g. `viper`). Never hard‑code secrets.

---

## How to Use This Reference

1. Apply `code-excellence` first.
2. Use this reference for Go‑specific implementation details.
3. Refer to "Effective Go" and "The Go Programming Language" for deeper
   understanding.
