# Go Best Practices (1.22+) — Expert Level

## Purpose

This reference encodes **Go‑specific expert practices** that, combined with
the parent `code-excellence` skill and its pattern catalog, guide AI to produce
production‑grade, idiomatic Go code.

---

## Go Language Idioms

- **Simplicity over cleverness** — Avoid deep abstractions, heavy reflection, or complex generics unless they clearly reduce duplication.
- **Small interfaces** — 1‑3 methods. Define where consumed, not where implemented.
- **Always check errors** — `if err != nil { return fmt.Errorf("context: %w", err) }`
- **defer for cleanup** — files, mutexes, contexts. LIFO order.
- **Zero values are useful** — `sync.Mutex` ready without init, nil slice can be appended.
- **Composition over inheritance** — embed structs, don't create deep hierarchies.

---

## Go 1.22+ Key Changes

### Loop Variable Semantics (FIXED)
```go
for _, v := range items {
    go func() { process(v) }() // 1.22+: safe — v is per-iteration
}
```

### Enhanced net/http Routing
```go
mux.HandleFunc("GET /users/{id}", handleGetUser)
mux.HandleFunc("POST /users", handleCreateUser)
id := r.PathValue("id")
```

### go.work for Multi-Module
```
go 1.22
use (./backend/auth; ./backend/orders)
```

---

## Memory Model & Performance

### Escape Analysis
- Values that don't escape the stack avoid heap allocation. This is the single biggest performance lever in Go.
- **How to check**: `go build -gcflags="-m"` shows escape decisions.
- **Common heap escape triggers**: returning a pointer to a local, storing into an interface, capturing in a closure sent to another goroutine.

```go
// Stack (fast, no GC) — value doesn't escape
func sum(vals []int) int { total := 0; /* ... */; return total }

// Heap (slower, GC pressure) — returned pointer escapes
func newUser(name string) *User { return &User{Name: name} }
```

### sync.Pool for Reusable Buffers
```go
var bufPool = sync.Pool{New: func() any { return new(bytes.Buffer) }}

func process(data []byte) {
    buf := bufPool.Get().(*bytes.Buffer)
    defer func() { buf.Reset(); bufPool.Put(buf) }()
    buf.Write(data)
    // ...
}
```

### Profiling Commands
```bash
go test -bench=. -cpuprofile=cpu.out
go tool pprof -http=:8080 cpu.out           # flame graph in browser

go test -bench=. -memprofile=mem.out
go tool pprof -http=:8080 mem.out           # allocation hotspots

go test -race ./...                          # race detector — ALWAYS in CI
```

---

## Deep Concurrency

### errgroup for Bounded Parallelism
```go
import "golang.org/x/sync/errgroup"

g, ctx := errgroup.WithContext(ctx)
g.SetLimit(10) // max 10 concurrent goroutines

for _, url := range urls {
    url := url
    g.Go(func() error { return fetch(ctx, url) })
}
if err := g.Wait(); err != nil { /* first error */ }
```

### Channel Patterns
```go
// Fan-in: merge multiple channels
func merge(cs ...<-chan int) <-chan int {
    var wg sync.WaitGroup
    out := make(chan int)
    for _, c := range cs {
        wg.Add(1)
        go func(c <-chan int) { for v := range c { out <- v }; wg.Done() }(c)
    }
    go func() { wg.Wait(); close(out) }()
    return out
}

// Or-Done: first one wins
select {
case <-ctx.Done(): return ctx.Err()
case result := <-work: return result, nil
case <-time.After(5 * time.Second): return nil, ErrTimeout
}
```

---

## Testing — Expert Patterns

### Golden Files
```go
func TestRender(t *testing.T) {
    got := Render(template, data)
    golden := filepath.Join("testdata", "expected.html")
    if *update { os.WriteFile(golden, []byte(got), 0644) }
    want, _ := os.ReadFile(golden)
    if diff := cmp.Diff(string(want), got); diff != "" {
        t.Errorf("mismatch (-want +got):\n%s", diff)
    }
}
```

### Fuzz Testing (Go 1.18+)
```go
func FuzzParse(f *testing.F) {
    f.Fuzz(func(t *testing.T, input string) {
        _, err := Parse(input)
        if err != nil { t.Skip() } // only care about panics/crashes
    })
}
```

---

## Production Patterns

### slog Structured Logging (1.21+)
```go
logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelInfo}))
logger.Info("order created", "orderId", id, "amount", amount, "traceId", traceId)
```

### Graceful Shutdown
```go
srv := &http.Server{Addr: ":8080"}
go srv.ListenAndServe()

quit := make(chan os.Signal, 1)
signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
<-quit

ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
defer cancel()
srv.Shutdown(ctx)
```

---

## How to Use This Reference

1. Apply `code-excellence` SKILL.md for the operation pipeline.
2. Consult `decision-trees.md` for design choices.
3. Use this reference for Go‑specific expert implementation.
4. For deeper dives: "Effective Go", "The Go Programming Language", go.dev/blog.
