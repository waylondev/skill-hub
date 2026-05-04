# Phase 10: Frontend Migration (BMS → React/Angular)

## Objective

Migrate ALL BMS (Basic Mapping Support) screens identified in Phase 3 into modern React or Angular single-page applications. Every BMS screen input/output field, PF key action, and screen navigation flow must be faithfully reproduced in the new frontend framework.

## Input

- Phase 3: BMS Screen Analysis (`03-screens/` directory)
- Phase 5: Logic Extraction — program-to-screen mappings
- Phase 6: Architecture Blueprint — navigation routing design
- Phase 8: DTO Specifications (Request/Response structures)
- Phase 8: REST API Specification (Controller endpoints)

## Deliverables

- `10-frontend-migration/component-mapping-table.md` — BMS field → UI component mapping
- `10-frontend-migration/screen-layouts/` — ASCII layout references from original BMS
- `10-frontend-migration/src/components/` — React/Angular component source files
- `10-frontend-migration/src/services/` — API integration service layer (fetch/axios)
- `10-frontend-migration/src/routing/` — Navigation routing configuration
- `10-frontend-migration/src/state/` — State management (Redux Toolkit / NgRx / Context)
- `10-frontend-migration/docker-compose.frontend.yml` — Local dev environment

## BMS → UI Component Mapping

| BMS Element | BMS Attribute | React Component | Angular Component | Notes |
|-------------|---------------|-----------------|-------------------|-------|
| `DFHMDF` UNPROT (input) | `ATTRB=(UNPROT,NORM)` | `<input>` / `<TextField>` | `<input matInput>` | Maps to Request DTO field |
| `DFHMDF` PROT (output) | `ATTRB=(PROT,NORM)` | `<span>` / `<Typography>` | `<span>` / `{{ }}` | Maps to Response DTO field |
| `DFHMDF` BRIGHT (highlight) | `ATTRB=(PROT,BRIGHT)` | `<span style={{fontWeight:'bold'}}>` | `<strong>` | Error messages, totals |
| `DFHMDF` DARK (hidden) | `ATTRB=(PROT,DARK)` | `<input type="hidden">` | `<input type="hidden">` | CSRF tokens, context IDs |
| `DFHMDF` ASKIP (skip) | `ATTRB=(ASKIP,NORM)` | Cursor logic in `<input>` | `tabindex="-1"` | Auto-tab between fields |
| `DFHMSD` MAP header | `MAPATTS=(COLOR,...)` | `<AppBar>` / `<Header>` | `<mat-toolbar>` | Screen title + date |
| PF1-PF24 keys | `EIBAID` | `<Button>` + keyboard shortcuts | `(keydown)` event binding | ENTER=Submit, PF3=Back |
| `DFHMDF` 88-level dropdown | `ATTRB=(UNPROT,NORM)` + validation | `<Select>` / `<Dropdown>` | `<mat-select>` | Enums from Phase 4 |
| List display (browse) | `SEND MAP` with repeated fields | `<Table>` / `<DataGrid>` | `<mat-table>` | Paginated, cursor-based |
| Error message line | `ATTRB=(PROT,BRIGHT)` row 24 | `<Alert>` / `<Snackbar>` | `<mat-error>` / `<snack-bar>` | RESP≠0 handling |

## State Management Approach

### Session Context (CommArea equivalent)

```javascript
// React: Redux Toolkit slice
const sessionSlice = createSlice({
  name: 'session',
  initialState: {
    userId: null,
    userName: null,
    currentScreen: null,
    parentScreen: null,
    commArea: {},        // cursor IDs, page nums, flags
    lastTransactionId: null,
    menuStack: []        // PF3 return path
  },
  reducers: {
    setUser(state, action) { ... },
    navigateTo(state, action) { ... },
    pushMenu(state, action) { ... },
    popMenu(state) { ... },
    updateCommArea(state, action) { ... }
  }
});
```

```typescript
// Angular: NgRx state
interface AppState {
  session: {
    userId: string | null;
    userName: string | null;
    currentScreen: string | null;
    parentScreen: string | null;
    commArea: Record<string, unknown>;
    menuStack: string[];
  };
}
```

### Screen State Pattern

Each BMS screen maps to a dedicated state slice:

```javascript
// Pattern per screen (e.g., COCRDUPC → Card Update screen)
{
  screenData: {
    cardNumber: '',        // UNPROT field
    cardHolderName: '',    // UNPROT field
    expiryDate: '',        // UNPROT field
    errorMessage: '',      // PROT BRIGHT on row 24
    successMessage: '',    // PROT on row 23
    isSubmitting: false
  },
  validation: {
    errors: {},            // Per-field validation errors
    touched: {}            // Track which fields user interacted with
  }
}
```

## API Integration Patterns

### Service Layer Architecture

```javascript
// React: Axios-based API service
const apiClient = axios.create({
  baseURL: '/api/v1',
  headers: { 'Content-Type': 'application/json' },
  timeout: 30000
});

apiClient.interceptors.request.use((config) => {
  const token = store.getState().session.jwtToken;
  if (token) config.headers.Authorization = `Bearer ${token}`;
  return config;
});

const cardService = {
  getInitialScreen: () => apiClient.get('/cards/update'),
  processUpdate: (request) => apiClient.post('/cards/update', request),
  browseForward: (cursor, pageSize = 10) =>
    apiClient.get('/cards/browse', { params: { cursor, direction: 'forward', pageSize } }),
  browseBackward: (cursor, pageSize = 10) =>
    apiClient.get('/cards/browse', { params: { cursor, direction: 'backward', pageSize } })
};
```

```typescript
// Angular: HttpClient-based service
@Injectable({ providedIn: 'root' })
export class CardService {
  constructor(private http: HttpClient) {}

  getInitialScreen(): Observable<CardUpdateResponse> {
    return this.http.get<CardUpdateResponse>('/api/v1/cards/update');
  }

  processUpdate(request: CardUpdateRequest): Observable<CardUpdateResponse> {
    return this.http.post<CardUpdateResponse>('/api/v1/cards/update', request);
  }

  browse(url: string): Observable<CursorPageResponse<CardDto>> {
    return this.http.get<CursorPageResponse<CardDto>>(url);
  }
}
```

### PF Key → HTTP Mapping

| CICS PF Key | HTTP Method | Endpoint Pattern | Request Body |
|-------------|-------------|-----------------|--------------|
| EIBCALEN=0 (initial) | GET | `/api/v1/{resource}/{action}` | — |
| DFHENTER (submit) | POST | `/api/v1/{resource}/{action}` | Full Request DTO |
| PF3 (return) | POST | `/api/v1/{resource}/return` | CommArea context |
| PF7 (prev page) | POST | `/api/v1/{resource}/browse` | `{ cursor, direction: 'backward' }` |
| PF8 (next page) | POST | `/api/v1/{resource}/browse` | `{ cursor, direction: 'forward' }` |
| PF4 (clear) | DELETE | `/api/v1/{resource}/context` | Current context |

## Navigation Routing

### React Router Configuration

```javascript
// Source: Phase 3 screen navigation + Phase 6 architecture
const routes = [
  { path: '/', element: <Navigate to="/login" /> },
  { path: '/login', element: <SignOnScreen /> },           // COSGN00C
  { path: '/menu', element: <MainMenuScreen /> },           // COADM01C
  { path: '/cards', element: <Layout />, children: [
    { path: '', element: <CardMenuScreen /> },              // COADM02C
    { path: 'create', element: <CardCreateScreen /> },      // COCRD01C
    { path: 'update', element: <CardUpdateScreen /> },      // COCRDUPC
    { path: 'view', element: <CardViewScreen /> },          // COACTVWC
    { path: 'delete', element: <CardDeleteScreen /> },      // COACTDLC
  ]},
  { path: '/accounts', element: <Layout />, children: [
    { path: '', element: <AccountMenuScreen /> },           // COADM03C
    { path: 'transactions', element: <TransactionListScreen /> }, // COTRN00C
  ]},
  { path: '/users', element: <Layout />, children: [
    { path: '', element: <UserListScreen /> },              // COUSR00C
    { path: 'create', element: <UserCreateScreen /> },      // COUSR01C
    { path: 'update', element: <UserUpdateScreen /> },      // COUSR02C
  ]},
  { path: '*', element: <NotFoundScreen /> }
];
```

### Angular Router Configuration

```typescript
const routes: Routes = [
  { path: '', redirectTo: '/login', pathMatch: 'full' },
  { path: 'login', component: SignOnScreenComponent },
  { path: 'menu', component: MainMenuScreenComponent },
  {
    path: 'cards',
    component: CardLayoutComponent,
    children: [
      { path: '', component: CardMenuScreenComponent },
      { path: 'create', component: CardCreateScreenComponent },
      { path: 'update', component: CardUpdateScreenComponent },
      { path: 'view', component: CardViewScreenComponent },
      { path: 'delete', component: CardDeleteScreenComponent }
    ]
  },
  {
    path: 'accounts',
    component: AccountLayoutComponent,
    children: [
      { path: '', component: AccountMenuScreenComponent },
      { path: 'transactions', component: TransactionListScreenComponent }
    ]
  },
  {
    path: 'users',
    component: UserLayoutComponent,
    children: [
      { path: '', component: UserListScreenComponent },
      { path: 'create', component: UserCreateScreenComponent },
      { path: 'update', component: UserUpdateScreenComponent }
    ]
  }
];
```

## Execution Steps

### Step 1: Extract BMS Screen Reference

Read ALL screen analysis documents from `03-screens/` directory. For each BMS mapset, identify:
- All `DFHMDF` field definitions with attributes (UNPROT/PROT/BRIGHT/DARK/ASKIP)
- Screen dimensions (24×80 typical)
- Title literals and constant text lines
- PF key assignments from the associated COBOL program

### Step 2: Build Component Mapping Table

For each BMS field, map to the appropriate UI component using the table above. Produce `component-mapping-table.md` with one row per BMS field.

### Step 3: Create Screen Layout References

Generate `screen-layouts/{mapname}.md` for each BMS map, preserving the original ASCII layout as a reference image for developers.

### Step 4: Generate State Management Configuration

Create the Redux Toolkit store (React) or NgRx store (Angular):
- Session slice (CommArea equivalent)
- Per-screen slices with form state, validation state, loading state
- API middleware (Redux Thunk / NgRx Effects)

### Step 5: Generate API Service Layer

For each REST endpoint defined in Phase 8 controller specs, create service functions:
- GET for initial screen display
- POST for form submission (ENTER key)
- POST with cursor for pagination (PF7/PF8)
- Error response handling mapped to UI error displays

### Step 6: Generate UI Components

For each BMS screen, generate the main page component:
- Form fields for ALL UNPROT inputs with Bean Validation mirroring
- Display fields for ALL PROT outputs
- Error/success message areas (rows 23-24 equivalent)
- PF key buttons with keyboard shortcuts
- Cursor positioning logic (tab order matching BMS cursor sequence)

### Step 7: Configure Routing

Generate routing configuration matching the CICS navigation graph from Phase 6. Ensure:
- PF3 (return) always navigates to parent screen
- Authentication guard on all routes except `/login`
- Deep linking support for bookmarked URLs

### Step 8: Generate Docker Compose for Local Dev

Create `docker-compose.frontend.yml` with:
- Node.js dev server with hot reload
- Proxy to Spring Boot backend
- Mock API server option for offline development

## Quality Gate

- [ ] Every BMS screen from Phase 3 has a corresponding UI component
- [ ] All UNPROT fields mapped to editable input components
- [ ] All PROT/BRIGHT fields mapped to display components
- [ ] All PF key actions mapped to button handlers
- [ ] PF3 always navigates to parent screen
- [ ] PF7/PF8 cursor-based pagination working end-to-end
- [ ] Validation errors displayed in error area (row 24 equivalent)
- [ ] Keyboard shortcuts functional for all PF keys
- [ ] Session CommArea state preserved across screen navigations
- [ ] API error responses (404, 409, 500) handled with user-facing messages
- [ ] `_state-snapshot.json` updated to `{'phase':10,'status':'complete'}`
