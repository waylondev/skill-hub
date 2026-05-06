# Frontend Excellence Reference

## Purpose

This reference defines production-grade standards for TypeScript/React frontend development. It covers type safety, component architecture, state management, performance, accessibility, testing, API integration, CSS architecture, build optimization, and common anti-patterns. Use this as the authoritative baseline for all frontend code review and generation.

---

## 1. TypeScript Strict Mode Best Practices

Enable the full strictness suite in `tsconfig.json`. Do not compromise on these flags.

```json
{
  "compilerOptions": {
    "strict": true,
    "strictNullChecks": true,
    "noImplicitAny": true,
    "strictFunctionTypes": true,
    "noUncheckedIndexedAccess": true,
    "exactOptionalPropertyTypes": true
  }
}
```

### strictNullChecks

Treat `null` and `undefined` as distinct types. The compiler forces explicit handling.

```typescript
// ❌ Without strictNullChecks — compiles, crashes at runtime
function getUserName(user: User): string {
  return user.profile.name; // runtime error if user.profile is null
}

// ✅ With strictNullChecks — compile-time safety
function getUserName(user: User): string {
  if (user.profile == null) {
    throw new Error("Profile not loaded");
  }
  return user.profile.name;
}

// ✅ Better: encode the requirement in the type
function getUserName(user: User & { profile: NonNullable<User["profile"]> }): string {
  return user.profile.name;
}
```

### noImplicitAny

Every parameter, return type, and variable must have an explicit or inferable type. No implicit `any`.

```typescript
// ❌ Implicit any — type safety lost
function process(data) { // data is implicitly any
  return data.value * 2;
}

// ✅ Explicit type contract
interface Processable {
  value: number;
}

function process(data: Processable): number {
  return data.value * 2;
}

// ✅ Or use unknown when the shape is truly unknown
function parseJson(input: string): unknown {
  return JSON.parse(input);
}

function extractName(data: unknown): string {
  if (
    typeof data === "object" &&
    data !== null &&
    "name" in data &&
    typeof data.name === "string"
  ) {
    return data.name;
  }
  throw new Error("Invalid data shape");
}
```

### strictFunctionTypes

Function parameters are checked contravariantly. Method bivariance is disabled.

```typescript
// ❌ Without strictFunctionTypes — unsound assignment allowed
type Handler = (value: string | number) => void;
const stringOnlyHandler: Handler = (value: string) => {
  console.log(value.toUpperCase()); // crashes if number is passed
};

// ✅ With strictFunctionTypes — compile error caught
const safeHandler: Handler = (value: string | number) => {
  if (typeof value === "string") {
    console.log(value.toUpperCase());
  }
};
```

### noUncheckedIndexedAccess

Index signatures return `T | undefined`, forcing null checks.

```typescript
const config: Record<string, string> = { apiUrl: "https://api.example.com" };

// ✅ Must handle the undefined case
const apiUrl = config["apiUrl"];
if (apiUrl != null) {
  fetch(apiUrl);
}
```

---

## 2. React Component Design Principles

### Single Responsibility

A component should do one thing. If the description contains "and", split it.

```typescript
// ❌ Does data fetching, formatting, and rendering
function UserDashboard() {
  const [user, setUser] = useState<User | null>(null);
  useEffect(() => { fetchUser().then(setUser); }, []);
  if (!user) return <Spinner />;
  return (
    <div>
      <h1>Welcome, {user.name.toUpperCase()}</h1>
      <p>Joined: {new Date(user.createdAt).toLocaleDateString()}</p>
    </div>
  );
}

// ✅ Separate concerns into dedicated components
function UserDashboard() {
  const { data: user, isLoading } = useUser();
  if (isLoading) return <Spinner />;
  if (!user) return <ErrorMessage code="USER_NOT_FOUND" />;
  return (
    <div>
      <UserGreeting user={user} />
      <UserMeta user={user} />
    </div>
  );
}

function UserGreeting({ user }: { user: User }) {
  return <h1>Welcome, {user.name}</h1>;
}

function UserMeta({ user }: { user: User }) {
  return <p>Joined: {formatDate(user.createdAt)}</p>;
}
```

### Explicit Props

Props interfaces should be complete, readonly, and avoid excessive optionality.

```typescript
// ❌ Vague, optional everything
interface Props {
  data?: any;
  onClick?: () => void;
}

// ✅ Explicit, narrow, required where appropriate
interface OrderCardProps {
  readonly order: Order;
  readonly onCancel: (orderId: string) => void;
  readonly variant?: "compact" | "detailed";
}

function OrderCard({ order, onCancel, variant = "compact" }: OrderCardProps) {
  // variant has a default; order and onCancel are required
}
```

### Composition Over Inheritance

Never inherit from React components. Use composition with `children` and slots.

```typescript
// ❌ Inheritance — fragile, tight coupling
class FancyButton extends Button {
  render() {
    return <button className="fancy">{this.props.label}</button>;
  }
}

// ✅ Composition — flexible, declarative
interface ButtonProps {
  readonly children: React.ReactNode;
  readonly variant?: "primary" | "secondary";
  readonly onClick: () => void;
}

function Button({ children, variant = "primary", onClick }: ButtonProps) {
  return (
    <button className={`btn btn--${variant}`} onClick={onClick}>
      {children}
    </button>
  );
}

// Usage: compose behavior through props and children
<Button variant="secondary" onClick={handleCancel}>
  <Icon name="x" /> Cancel
</Button>
```

### Controlled vs Uncontrolled

| Scenario | Pattern |
|----------|---------|
| Form data needed by parent | **Controlled** — state lifted, `value` + `onChange` |
| Self-contained input with no external consumers | **Uncontrolled** — `useRef` + `<input defaultValue>` |
| Complex form with validation | **Controlled** — React Hook Form or Formik |
| One-off toggle inside a card | **Uncontrolled** — `useState` local to component |

```typescript
// ✅ Controlled — parent owns the state
function SearchInput({
  value,
  onChange,
}: {
  value: string;
  onChange: (value: string) => void;
}) {
  return (
    <input
      type="search"
      value={value}
      onChange={(e) => onChange(e.target.value)}
      aria-label="Search"
    />
  );
}

// ✅ Uncontrolled — component owns ephemeral state
function ExpandableSection({ title, children }: { title: string; children: React.ReactNode }) {
  const [isOpen, setIsOpen] = useState(false);
  return (
    <div>
      <button onClick={() => setIsOpen((v) => !v)}>{title}</button>
      {isOpen && <div>{children}</div>}
    </div>
  );
}
```

---

## 3. State Management Decision Tree

Choose the simplest tool that satisfies the requirement. Do not default to Redux.

```
Does any other component need this state?
├── NO → useState / useReducer (Local State)
│
├── YES → How deeply nested is the consumer?
│   ├── Same parent / 1-2 levels → Lift state to common ancestor
│   │
│   ├── 3+ levels, moderate update frequency → React Context
│   │
│   ├── Global, high-frequency updates (animations, real-time) → Zustand
│   │
│   ├── Complex domain logic, time-travel debugging, middleware → Redux Toolkit
│   │
│   └── Server-cached data (lists, details, mutations) → TanStack Query / SWR
```

| Tool | Use When | Do NOT Use When |
|------|----------|-----------------|
| **useState/useReducer** | Component-local or sibling-shared state | Prop drilling exceeds 2 levels |
| **Context** | Theme, locale, auth session, static config | High-frequency updates (>10/sec) |
| **Zustand** | Global UI state, cross-cutting concerns | Server state — use React Query |
| **Redux Toolkit** | Complex state machines, devtools required, middleware | Simple boolean toggles |
| **TanStack Query** | Server state: fetch, cache, invalidate, mutate | Client-only ephemeral UI state |

```typescript
// ✅ Zustand — minimal boilerplate, TypeScript-native
import { create } from "zustand";

interface CartStore {
  items: CartItem[];
  addItem: (item: CartItem) => void;
  removeItem: (id: string) => void;
}

const useCartStore = create<CartStore>((set) => ({
  items: [],
  addItem: (item) => set((state) => ({ items: [...state.items, item] })),
  removeItem: (id) => set((state) => ({ items: state.items.filter((i) => i.id !== id) })),
}));

// Selector usage — only re-renders when items change
const itemCount = useCartStore((s) => s.items.length);
```

---

## 4. Frontend Performance Optimization Patterns

### Code Splitting & Lazy Loading

Split by route and by heavy components. Never load the entire application upfront.

```typescript
import { lazy, Suspense } from "react";

// ✅ Route-level splitting
const AdminPanel = lazy(() => import("./pages/AdminPanel"));
const Reports = lazy(() => import("./pages/Reports"));

function App() {
  return (
    <Suspense fallback={<PageSkeleton />}>
      <Routes>
        <Route path="/admin" element={<AdminPanel />} />
        <Route path="/reports" element={<Reports />} />
      </Routes>
    </Suspense>
  );
}

// ✅ Component-level splitting for heavy dependencies
const HeavyChart = lazy(() => import("./components/HeavyChart"));

function Dashboard() {
  return (
    <div>
      <KpiCards />
      <Suspense fallback={<ChartPlaceholder />}>
        <HeavyChart data={data} />
      </Suspense>
    </div>
  );
}
```

### Memoization

Memoize expensive computations and stable callbacks. Do not memoize everything — measure first.

```typescript
import { memo, useMemo, useCallback } from "react";

// ✅ memo for pure components receiving stable props
const ProductCard = memo(function ProductCard({ product, onAdd }: ProductCardProps) {
  return (
    <div>
      <h3>{product.name}</h3>
      <button onClick={() => onAdd(product.id)}>Add to Cart</button>
    </div>
  );
});

function ProductList({ products, category }: { products: Product[]; category: string }) {
  // ✅ useMemo for expensive filtering
  const filtered = useMemo(
    () => products.filter((p) => p.category === category),
    [products, category]
  );

  // ✅ useCallback for stable function references passed to children
  const handleAdd = useCallback((id: string) => {
    cartStore.addItem(id);
  }, []);

  return (
    <div>
      {filtered.map((p) => (
        <ProductCard key={p.id} product={p} onAdd={handleAdd} />
      ))}
    </div>
  );
}
```

### Virtualization

Render only visible rows. Essential for lists > 100 items.

```typescript
import { useVirtualizer } from "@tanstack/react-virtual";

function VirtualizedList({ items }: { items: Item[] }) {
  const parentRef = useRef<HTMLDivElement>(null);
  const virtualizer = useVirtualizer({
    count: items.length,
    getScrollElement: () => parentRef.current,
    estimateSize: () => 48,
  });

  return (
    <div ref={parentRef} style={{ height: "400px", overflow: "auto" }}>
      <div style={{ height: `${virtualizer.getTotalSize()}px`, position: "relative" }}>
        {virtualizer.getVirtualItems().map((virtualItem) => (
          <div
            key={virtualItem.key}
            style={{
              position: "absolute",
              top: 0,
              left: 0,
              width: "100%",
              height: `${virtualItem.size}px`,
              transform: `translateY(${virtualItem.start}px)`,
            }}
          >
            {items[virtualItem.index].name}
          </div>
        ))}
      </div>
    </div>
  );
}
```

### Image Optimization

```typescript
// ✅ Use modern formats, explicit dimensions, lazy loading
function OptimizedImage({ src, alt, width, height }: ImageProps) {
  return (
    <img
      src={src}
      alt={alt}
      width={width}
      height={height}
      loading="lazy"
      decoding="async"
      style={{ maxWidth: "100%", height: "auto" }}
    />
  );
}

// ✅ Responsive images with srcset
<picture>
  <source srcSet="/image.avif" type="image/avif" />
  <source srcSet="/image.webp" type="image/webp" />
  <img src="/image.jpg" alt="Description" width={800} height={600} loading="lazy" />
</picture>
```

---

## 5. Accessibility (a11y) Checklist

Accessibility is not a feature — it is a baseline requirement.

### ARIA Labels

Use semantic HTML first. Add ARIA only when HTML semantics are insufficient.

```typescript
// ❌ Unnecessary ARIA on semantic element
<button aria-role="button" onClick={handleClick}>Save</button>

// ✅ Semantic HTML is self-describing
<button onClick={handleClick}>Save</button>

// ✅ ARIA when semantics are missing
<div role="button" tabIndex={0} onClick={handleClick} onKeyDown={handleKeyDown}>
  Save
</div>

// ✅ Descriptive labels for icon-only buttons
<button aria-label="Close dialog" onClick={onClose}>
  <Icon name="x" aria-hidden="true" />
</button>
```

### Keyboard Navigation

All interactive elements must be reachable and operable via keyboard.

```typescript
// ✅ Trap focus inside modals
function Modal({ isOpen, onClose, children }: ModalProps) {
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!isOpen) return;
    const firstFocusable = ref.current?.querySelector<HTMLElement>(
      'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
    );
    firstFocusable?.focus();
  }, [isOpen]);

  return (
    <div ref={ref} role="dialog" aria-modal="true">
      {children}
    </div>
  );
}
```

### Focus Management

```typescript
// ✅ Restore focus after action
function DeleteButton({ itemId }: { itemId: string }) {
  const buttonRef = useRef<HTMLButtonElement>(null);

  const handleDelete = async () => {
    await deleteItem(itemId);
    buttonRef.current?.focus();
  };

  return <button ref={buttonRef} onClick={handleDelete}>Delete</button>;
}
```

### Color Contrast

- Normal text: minimum 4.5:1 against background
- Large text (18pt+ or 14pt bold): minimum 3:1
- UI components and graphical objects: minimum 3:1

```typescript
// ✅ Never rely on color alone
function StatusBadge({ status }: { status: "success" | "error" | "warning" }) {
  const config = {
    success: { label: "Completed", color: "green", icon: "check" },
    error: { label: "Failed", color: "red", icon: "alert" },
    warning: { label: "Pending", color: "orange", icon: "clock" },
  };
  const { label, color, icon } = config[status];
  return (
    <span className={`badge badge--${color}`}>
      <Icon name={icon} aria-hidden="true" />
      {label}
    </span>
  );
}
```

### Screen Reader Testing

Test with actual screen readers (NVDA, JAWS, VoiceOver) and automated tools:

```bash
# axe-core via jest-axe
npm install --save-dev jest-axe @types/jest-axe

// In component tests
import { axe, toHaveNoViolations } from "jest-axe";
expect.extend(toHaveNoViolations);

it("has no accessibility violations", async () => {
  const { container } = render(<UserProfile />);
  expect(await axe(container)).toHaveNoViolations();
});
```

---

## 6. Frontend Testing Patterns

### React Testing Library

Test behavior, not implementation. Query as the user would interact.

```typescript
import { render, screen, fireEvent, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";

// ✅ Query by role, label, or text — not by test-id
it("submits the form with valid data", async () => {
  const onSubmit = vi.fn();
  render(<LoginForm onSubmit={onSubmit} />);

  await userEvent.type(screen.getByLabelText(/email/i), "user@example.com");
  await userEvent.type(screen.getByLabelText(/password/i), "password123");
  await userEvent.click(screen.getByRole("button", { name: /sign in/i }));

  await waitFor(() => {
    expect(onSubmit).toHaveBeenCalledWith({
      email: "user@example.com",
      password: "password123",
    });
  });
});

// ❌ Do not test implementation details
it("calls setState on click", () => {
  const wrapper = shallow(<Counter />); // Enzyme-style — avoid
  wrapper.find("button").simulate("click");
  expect(wrapper.state("count")).toBe(1); // tests internals, not behavior
});
```

### Playwright (E2E)

Test critical user journeys across real browsers.

```typescript
import { test, expect } from "@playwright/test";

test("user can complete checkout", async ({ page }) => {
  await page.goto("/products");
  await page.getByRole("button", { name: "Add to Cart" }).first().click();
  await page.getByRole("link", { name: /cart/i }).click();
  await page.getByRole("button", { name: /checkout/i }).click();

  await page.getByLabelText(/email/i).fill("test@example.com");
  await page.getByRole("button", { name: /place order/i }).click();

  await expect(page.getByText(/order confirmed/i)).toBeVisible();
});
```

### Visual Regression

Catch unintended UI changes.

```typescript
// Chromatic / Storybook
import type { Meta, StoryObj } from "@storybook/react";

const meta: Meta<typeof Button> = {
  component: Button,
  parameters: {
    chromatic: { disableSnapshot: false },
  },
};

export const Primary: StoryObj<typeof Button> = {
  args: { variant: "primary", children: "Click me" },
};
```

---

## 7. API Integration Patterns

### Server State with TanStack Query

Treat server state as a cache: stale-while-revalidate, background refetch, automatic deduplication.

```typescript
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";

// ✅ Query with proper keys and error handling
function useUser(userId: string) {
  return useQuery({
    queryKey: ["users", userId],
    queryFn: () => api.getUser(userId),
    staleTime: 5 * 60 * 1000, // 5 minutes
    gcTime: 10 * 60 * 1000,   // 10 minutes
    retry: (failureCount, error) => {
      if (error.status === 404) return false; // do not retry not-found
      return failureCount < 3;
    },
  });
}

// ✅ Mutation with optimistic updates and cache invalidation
function useUpdateUser() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (data: UserUpdate) => api.updateUser(data),
    onMutate: async (newData) => {
      await queryClient.cancelQueries({ queryKey: ["users", newData.id] });
      const previous = queryClient.getQueryData<User>(["users", newData.id]);
      queryClient.setQueryData(["users", newData.id], (old: User | undefined) =>
        old ? { ...old, ...newData } : old
      );
      return { previous };
    },
    onError: (err, newData, context) => {
      if (context?.previous) {
        queryClient.setQueryData(["users", newData.id], context.previous);
      }
    },
    onSettled: (data, error, variables) => {
      queryClient.invalidateQueries({ queryKey: ["users", variables.id] });
    },
  });
}
```

### Error Boundaries

Catch rendering errors and prevent total UI collapse.

```typescript
import { Component, type ReactNode } from "react";

interface Props {
  children: ReactNode;
  fallback: ReactNode;
}

interface State {
  hasError: boolean;
  error?: Error;
}

class ErrorBoundary extends Component<Props, State> {
  state: State = { hasError: false };

  static getDerivedStateFromError(error: Error): State {
    return { hasError: true, error };
  }

  componentDidCatch(error: Error, info: React.ErrorInfo) {
    logErrorToService(error, info.componentStack);
  }

  render() {
    if (this.state.hasError) {
      return this.props.fallback;
    }
    return this.props.children;
  }
}

// Usage
<ErrorBoundary fallback={<ErrorPage />}>
  <UserDashboard />
</ErrorBoundary>
```

### Loading States

```typescript
// ✅ Coordinated loading with skeleton screens
function OrderPage({ orderId }: { orderId: string }) {
  const { data: order, isLoading, error } = useOrder(orderId);

  if (isLoading) return <OrderSkeleton />;
  if (error) return <ErrorMessage error={error} />;
  if (!order) return <NotFound resource="Order" />;

  return <OrderDetail order={order} />;
}
```

---

## 8. CSS Architecture

### CSS Modules

Scoped styles with explicit class mapping. Zero runtime overhead.

```typescript
// Button.module.css
.button { padding: 0.5rem 1rem; border-radius: 0.25rem; }
.primary { background: var(--color-primary); color: white; }
.secondary { background: var(--color-surface); color: var(--color-text); }

// Button.tsx
import styles from "./Button.module.css";

function Button({ variant = "primary", children }: ButtonProps) {
  return <button className={`${styles.button} ${styles[variant]}`}>{children}</button>;
}
```

### Tailwind CSS

Utility-first for rapid development. Use `@apply` sparingly; prefer composition.

```typescript
// ✅ Compose utilities, avoid arbitrary values
function Alert({ variant, children }: AlertProps) {
  const variantClasses = {
    info: "bg-blue-50 text-blue-800 border-blue-200",
    error: "bg-red-50 text-red-800 border-red-200",
    success: "bg-green-50 text-green-800 border-green-200",
  };

  return (
    <div className={`rounded-lg border p-4 ${variantClasses[variant]}`} role="alert">
      {children}
    </div>
  );
}
```

### CSS-in-JS (Styled Components / Emotion)

Use when dynamic styling depends on props/theme. Accept the runtime cost.

```typescript
import styled from "@emotion/styled";

const Button = styled.button<{ variant: "primary" | "secondary" }>`
  padding: 0.5rem 1rem;
  border-radius: 0.25rem;
  background: ${(p) => (p.variant === "primary" ? p.theme.colors.primary : p.theme.colors.surface)};
  color: ${(p) => (p.variant === "primary" ? "white" : p.theme.colors.text)};
`;
```

### Design Tokens

Centralize the design language. Never hardcode values.

```typescript
// tokens.ts
export const tokens = {
  color: {
    primary: "#2563eb",
    surface: "#ffffff",
    text: "#1f2937",
    error: "#dc2626",
  },
  spacing: {
    xs: "0.25rem",
    sm: "0.5rem",
    md: "1rem",
    lg: "1.5rem",
    xl: "2rem",
  },
  radius: {
    sm: "0.25rem",
    md: "0.5rem",
    lg: "1rem",
  },
} as const;

// Usage
<div style={{ padding: tokens.spacing.md, color: tokens.color.text }} />
```

| Approach | Best For | Avoid When |
|----------|----------|------------|
| **CSS Modules** | Component libraries, design systems, performance-critical apps | Rapid prototyping, heavy theming |
| **Tailwind** | Rapid development, consistent utility-based design | Heavy dynamic styling, runtime theme switching |
| **CSS-in-JS** | Theme-dependent dynamic styles, React-only ecosystems | Bundle size critical, SSR hydration sensitive |

---

## 9. Build Optimization

### Tree Shaking

Ensure ESM exports and avoid side-effectful imports.

```typescript
// ✅ Named exports are tree-shakeable
export function formatDate(date: Date): string { ... }
export function parseDate(input: string): Date { ... }

// ❌ Barrel files re-export everything — can defeat tree shaking
// utils/index.ts
export * from "./formatDate"; // may pull in unused code
export * from "./heavyChart"; // always included even if unused

// ✅ Import directly from the module
import { formatDate } from "@/utils/formatDate";
```

### Bundle Analysis

```bash
# webpack-bundle-analyzer
npm install --save-dev webpack-bundle-analyzer

# Add to vite.config.ts
import { visualizer } from "rollup-plugin-visualizer";

export default defineConfig({
  plugins: [
    visualizer({
      open: true,
      gzipSize: true,
      brotliSize: true,
    }),
  ],
});
```

Analyze output regularly. Targets:
- Initial JS < 200 KB gzipped
- Largest async chunk < 500 KB gzipped
- Third-party dependencies audited for duplication

### CDN Caching

```typescript
// ✅ Hash in filename for immutable assets
// vite.config.ts
export default defineConfig({
  build: {
    rollupOptions: {
      output: {
        entryFileNames: "assets/[name]-[hash].js",
        chunkFileNames: "assets/[name]-[hash].js",
        assetFileNames: "assets/[name]-[hash][extname]",
      },
    },
  },
});
```

```nginx
# Cache immutable assets for 1 year
location /assets/ {
    add_header Cache-Control "public, max-age=31536000, immutable";
}

# HTML entry point — never cache
location /index.html {
    add_header Cache-Control "no-cache, no-store, must-revalidate";
}
```

---

## 10. Common Frontend Anti-Patterns

### AP-F1: Prop Drilling

**Symptom**: Passing props through 3+ layers of components that do not use the data.

```typescript
// ❌ Prop drilling — every layer is coupled to data it does not need
function App() {
  const [user, setUser] = useState<User | null>(null);
  return <Layout user={user} setUser={setUser} />;
}
function Layout({ user, setUser }: any) {
  return <Header user={user} setUser={setUser} />;
}
function Header({ user, setUser }: any) {
  return <UserMenu user={user} setUser={setUser} />;
}

// ✅ Fix: Context or state management
function App() {
  return (
    <UserProvider>
      <Layout />
    </UserProvider>
  );
}
function UserMenu() {
  const { user, logout } = useUser(); // consumed exactly where needed
  return <div>{user?.name}</div>;
}
```

### AP-F2: Excessive Re-Renders

**Symptom**: Components re-render on every frame due to unstable references or context splitting.

```typescript
// ❌ New object on every render — child re-renders unnecessarily
function Parent() {
  const [count, setCount] = useState(0);
  const config = { threshold: 10 }; // new reference every render
  return <Child config={config} />;
}

// ✅ Memoize static objects or lift them out
const STATIC_CONFIG = { threshold: 10 };

function Parent() {
  const [count, setCount] = useState(0);
  return <Child config={STATIC_CONFIG} />;
}

// ✅ Or useMemo for derived objects
function Parent({ baseThreshold }: { baseThreshold: number }) {
  const config = useMemo(() => ({ threshold: baseThreshold * 2 }), [baseThreshold]);
  return <Child config={config} />;
}
```

### AP-F3: Large Bundle Sizes

**Symptom**: Importing entire libraries for one function.

```typescript
// ❌ Imports entire lodash — +70 KB
import _ from "lodash";
_.debounce(fn, 300);

// ✅ Import only what you need
import debounce from "lodash/debounce";

// ✅ Or use lighter alternatives
import { debounce } from "es-toolkit";
```

### AP-F4: Inline Styles

**Symptom**: `style={{ ... }}` used for static styling, preventing caching and increasing bundle size.

```typescript
// ❌ Inline styles — no caching, hard to override, no media queries
function Card({ children }: { children: React.ReactNode }) {
  return (
    <div style={{ padding: "16px", borderRadius: "8px", boxShadow: "0 2px 4px rgba(0,0,0,0.1)" }}>
      {children}
    </div>
  );
}

// ✅ CSS Module or utility class
import styles from "./Card.module.css";

function Card({ children }: { children: React.ReactNode }) {
  return <div className={styles.card}>{children}</div>;
}
```

### AP-F5: useEffect Abuse

**Symptom**: Using `useEffect` for derived state or synchronous side effects that should be event-driven.

```typescript
// ❌ Derived state in useEffect — desynchronized, extra render
function FilteredList({ items, query }: { items: Item[]; query: string }) {
  const [filtered, setFiltered] = useState<Item[]>([]);
  useEffect(() => {
    setFiltered(items.filter((i) => i.name.includes(query)));
  }, [items, query]);
  return <List items={filtered} />;
}

// ✅ Derive during render — single source of truth
function FilteredList({ items, query }: { items: Item[]; query: string }) {
  const filtered = useMemo(() => items.filter((i) => i.name.includes(query)), [items, query]);
  return <List items={filtered} />;
}
```

### AP-F6: Missing Cleanup in useEffect

**Symptom**: Subscriptions, timers, or event listeners leak after unmount.

```typescript
// ❌ Leaked subscription
useEffect(() => {
  const ws = new WebSocket(url);
  ws.onmessage = (e) => setData(e.data);
}, [url]); // socket never closed

// ✅ Proper cleanup
useEffect(() => {
  const ws = new WebSocket(url);
  ws.onmessage = (e) => setData(e.data);
  return () => ws.close();
}, [url]);
```

### AP-F7: Any in Component Props

**Symptom**: Props typed as `any`, `object`, or missing interfaces.

```typescript
// ❌ Untyped props
function UserCard(props: any) {
  return <div>{props.name}</div>;
}

// ✅ Explicit, readonly interface
interface UserCardProps {
  readonly user: User;
  readonly onEdit: (id: string) => void;
}

function UserCard({ user, onEdit }: UserCardProps) {
  return <div onClick={() => onEdit(user.id)}>{user.name}</div>;
}
```

---

## Quick Checklist

Use this checklist before committing frontend code or completing a code review.

### TypeScript
- [ ] `strict: true` enabled in `tsconfig.json`
- [ ] No `any` types in component props or API contracts
- [ ] All nullable values explicitly handled (`null`, `undefined`)
- [ ] Function return types declared on public APIs

### React Components
- [ ] Each component has a single, describable responsibility
- [ ] Props interface is explicit, readonly, and narrowly typed
- [ ] Composition used instead of inheritance
- [ ] Controlled vs uncontrolled choice is deliberate and documented

### State Management
- [ ] Local state tried first before reaching for global stores
- [ ] Server state managed by TanStack Query / SWR, not Redux
- [ ] Context used only for low-frequency updates (theme, auth, locale)
- [ ] No prop drilling beyond 2 levels

### Performance
- [ ] Routes and heavy components are code-split with `React.lazy`
- [ ] `memo`, `useMemo`, `useCallback` applied to measured bottlenecks only
- [ ] Lists > 100 items are virtualized
- [ ] Images use `loading="lazy"`, explicit dimensions, and modern formats
- [ ] Bundle analyzed quarterly; largest chunk < 500 KB gzipped

### Accessibility
- [ ] All interactive elements reachable via keyboard (`Tab`, `Enter`, `Space`)
- [ ] ARIA labels present only where HTML semantics are insufficient
- [ ] Color contrast meets WCAG 2.1 AA (4.5:1 for normal text)
- [ ] Focus management implemented for modals and dynamic content
- [ ] `jest-axe` or equivalent passes in component tests

### Testing
- [ ] Components tested via React Testing Library (behavior, not internals)
- [ ] Critical user journeys covered by Playwright E2E tests
- [ ] Visual regression baseline established for UI components

### API Integration
- [ ] Server state fetched via TanStack Query with proper query keys
- [ ] Mutations invalidate relevant queries on success
- [ ] Error boundaries wrap route-level and feature-level components
- [ ] Loading skeletons shown instead of generic spinners

### CSS & Styling
- [ ] No inline styles for static presentation
- [ ] Design tokens used for colors, spacing, and typography
- [ ] Approach (CSS Modules / Tailwind / CSS-in-JS) chosen deliberately per project

### Build & Deployment
- [ ] Tree shaking verified via bundle analyzer
- [ ] Immutable assets served with `Cache-Control: immutable`
- [ ] Entry HTML served with `no-cache`
- [ ] No unused dependencies in `package.json`

### Anti-Patterns Scan
- [ ] No prop drilling through non-consuming layers
- [ ] No unstable object/array references passed as props
- [ ] No full-library imports (lodash, moment) — use modular imports
- [ ] No `useEffect` for derived state — compute during render
- [ ] All subscriptions and timers cleaned up on unmount
- [ ] No `any` in component props or API response types
