# Phase 8c: OpenAPI 3.0 Specification Generation

> **DEPENDS ON:** Phase 3 (BMS) + Phase 8 (API Endpoints) + Phase 8a (DTOs)  
> **OUTPUT:** `08-deliverables/openapi-spec.yaml`

## Objective

Generate a complete OpenAPI 3.0 YAML specification document covering all REST endpoints derived from BMS CICS screens. This spec serves as both API documentation and the contract for front-end development.

## Why This Phase Is Critical

- Front-end developers need a machine-readable API contract
- Swagger UI provides interactive API documentation
- OpenAPI spec enables automated client SDK generation (TypeScript fetch API client)
- API gateway configuration can be derived from the spec
- Contract testing (Pact) uses OpenAPI schema validation

## Generation Rules

### Rule 1: Every BMS Screen Generates Endpoints

| CICS BMS Flow | HTTP Method | URL Pattern |
|--------------|------------|------------|
| EIBCALEN=0 (initial display) | GET | `/api/v1/[resource]` |
| DFHENTER (process request) | POST | `/api/v1/[resource]` |
| PF5 (save/update) | PUT | `/api/v1/[resource]/{id}` |
| PF12 (delete/cancel) | DELETE | `/api/v1/[resource]/{id}` |
| PF7/PF8 (pagination) | GET (query params) | `/api/v1/[resource]?page=N` |

### Rule 2: BMS Field → OpenAPI Schema

| BMS Attribute | OpenAPI Schema Property |
|--------------|------------------------|
| UNPROT, X(N) | `type: string, maxLength: N` + `required` |
| UNPROT, 9(N) | `type: string, pattern: '^\\d{N}$'` |
| PROT, X(N) | `type: string, maxLength: N, readOnly: true` |
| PROT, formatted amount | `type: string, readOnly: true` |
| Array display (rows) | `type: array, items: { $ref: ... }` |

## Generated OpenAPI Spec

```yaml
# ============================================================
# CardDemo v4 — OpenAPI 3.0 Specification
# Source: BMS Map Analysis (Phase 3) + API Specification (Phase 8)
# Generated: YYYY-MM-DD
# ============================================================

openapi: 3.0.3
info:
  title: CardDemo API — COBOL CICS to Spring Boot Migration
  description: |
    REST API for CardDemo credit card management system.
    Migrated from CICS/VSAM COBOL + DB2 + IMS + MQ.
    Every endpoint traces back to an original CICS BMS screen.
  version: 1.0.0
  contact:
    name: CardDemo Migration Team

servers:
  - url: /api/v1
    description: API Gateway (Spring Cloud Gateway)

tags:
  - name: Authentication
    description: Login/logout — from COSGN00.bms
  - name: Accounts
    description: Account view/update — from COACTVW/COACTUP.bms
  - name: Cards
    description: Card list/detail/update — from COCRDLI/COCRDSL/COCRDUP.bms
  - name: Transactions
    description: Transaction list/detail/create — from COTRN00/01/02.bms
  - name: Payments
    description: Bill payment — from COBIL00.bms
  - name: Reports
    description: Transaction reports — from CORPT00.bms
  - name: Admin - Users
    description: Admin user management — from COUSR00-03.bms
  - name: Admin - Transaction Types
    description: Admin tran type management (DB2) — from COTRTLI/COTRTUP.bms
  - name: Admin - Authorization
    description: Auth summary/detail view (IMS) — from COPAU00/01.bms

components:
  securitySchemes:
    bearerAuth:
      type: http
      scheme: bearer
      bearerFormat: JWT
      description: |
        JWT token from POST /auth/login.
        COBOL equivalent: CICS EIBCALEN validation + USRSEC lookup.

  schemas:
    # --- Common ---
    ErrorResponse:
      type: object
      properties:
        errorCode:
          type: string
          description: COBOL RESP code equivalent (NOTFND, DUPKEY, etc.)
        message:
          type: string
          description: Human-readable error (from COBOL ERRMSGO field)
        timestamp:
          type: string
          format: date-time
        fieldErrors:
          type: array
          items:
            $ref: '#/components/schemas/FieldError'

    FieldError:
      type: object
      properties:
        field:
          type: string
          description: BMS field name that failed validation
        message:
          type: string
          description: COBOL IF validation error text

    CursorPageResponse:
      type: object
      description: |
        Cursor-based pagination (CICS STARTBR/READNEXT pattern).
        PF7=previous page, PF8=next page.

    # --- Authentication ---
    LoginRequest:
      type: object
      required: [userId, password]
      properties:
        userId:
          type: string
          maxLength: 8
          description: Source USERIDI (COSGN0A map, BMS UNPROT, X(08))
        password:
          type: string
          maxLength: 8
          format: password
          description: Source PASSWORDI (COSGN0A map, BMS UNPROT/DRK, X(08))

    LoginResponse:
      type: object
      properties:
        token:
          type: string
          description: JWT access token
        userType:
          type: string
          enum: [ADMIN, USER]
          description: Source SEC-USR-TYPE (CSUSR01Y.cpy, 88-level)
        userName:
          type: string
          description: Source SEC-USR-NAME (CSUSR01Y.cpy)

    # --- Account ---
    AccountViewResponse:
      type: object
      description: Source COACTVW.bms PROT fields + CommArea
      properties:
        title:
          type: string
          readOnly: true
          description: Source COTTL01Y.cpy
        curDate:
          type: string
          readOnly: true
          description: Source CSDAT01Y.cpy, FORMATTIME
        errorMessage:
          type: string
          readOnly: true
          description: Source CCARD-ERROR-MSG (CommArea COCOM01Y.cpy)
        accountInfo:
          $ref: '#/components/schemas/AccountInfo'
        customerInfo:
          $ref: '#/components/schemas/CustomerInfo'
        cards:
          type: array
          items:
            $ref: '#/components/schemas/CardSummary'

    AccountInfo:
      type: object
      description: PROT fields from COACTVW.bms
      properties:
        acctId:
          type: string
          readOnly: true
          description: Source ACCTIDO, PROT
        status:
          type: string
          readOnly: true
          description: Source STATUSO, PROT. 88-level: A=Active, I=Inactive
        currBal:
          type: string
          readOnly: true
          description: Source CURRBALO, PROT. Formatted PIC S9(9)V99
        creditLimit:
          type: string
          readOnly: true
        cashCreditLimit:
          type: string
          readOnly: true
        interestRate:
          type: string
          readOnly: true

    AccountUpdateRequest:
      type: object
      description: Source CAUPA map (COACTUP.bms) UNPROT fields
      required: [acctId]
      properties:
        acctId:
          type: string
          pattern: '^\d{11}$'
          description: Source ACCTIDI, UNPROT, X(11). COBOL: IF NOT NUMERIC → error
        creditLimit:
          type: number
          minimum: 0.01
          description: Source CREDLIMI, UNPROT, PIC S9(7)V99
        cashCreditLimit:
          type: number
          description: Source CASHCRLI, UNPROT, PIC S9(5)V99
        billingCycle:
          type: integer
          minimum: 1
          maximum: 31
          description: Source BILLCYCI, UNPROT, PIC 9(2)
        interestRate:
          type: number
          description: Source INTRATEI, UNPROT, PIC S9(2)V99

    # --- Card ---
    CardUpdateRequest:
      type: object
      description: Source COCRDUP.bms CCRDUPA map UNPROT fields. State: NOT_FETCHED→SHOW_DETAILS→CHANGES_OK→SAVED
      properties:
        cardNum:
          type: string
          maxLength: 16
          description: Source CARDNUMI, UNPROT
        cardStatus:
          type: string
          enum: [A, I, L]
          description: Source CARDSTAI, UNPROT
        nameOnCard:
          type: string
          maxLength: 30
          description: Source CARDNAMEI, UNPROT
        primaryFlag:
          type: string
          enum: [Y, N]
          description: Source CARDPRIMI, UNPROT
        action:
          type: string
          enum: [SEARCH, SAVE, CANCEL]
          description: CICS PF key equivalent (ENTER=SEARCH, PF5=SAVE, PF3=CANCEL)

    CardUpdateResponse:
      type: object
      properties:
        errorMessage:
          type: string
        state:
          type: string
          enum: [NOT_FETCHED, SHOW_DETAILS, CHANGES_NOT_OK, CHANGES_OK, SAVED]
        cardDetail:
          $ref: '#/components/schemas/CardDetail'
        fieldErrors:
          type: array
          items:
            type: string

    # --- Transaction ---
    TransactionCreateRequest:
      type: object
      required: [cardNum, tranType, tranAmt]
      description: Source COTRN02.bms UNPROT fields
      properties:
        cardNum:
          type: string
          description: Source CARDNUMI, UNPROT
          maxLength: 16
        tranType:
          type: string
          description: Source TRANTYPEI, UNPROT
          maxLength: 2
        tranCatCd:
          type: string
          maxLength: 2
        tranAmt:
          type: number
          exclusiveMinimum: 0
          description: Source TRANAMTI, UNPROT. COBOL: IF TRANAMTI ≤ 0 → error
        merchantName:
          type: string
          maxLength: 30
        merchantCity:
          type: string
          maxLength: 20
        merchantState:
          type: string
          maxLength: 2
        merchantId:
          type: string
          maxLength: 15

    TransactionListResponse:
      allOf:
        - $ref: '#/components/schemas/CursorPageResponse'
        - type: object
          properties:
            transactions:
              type: array
              items:
                $ref: '#/components/schemas/TransactionSummary'

    TransactionSummary:
      type: object
      description: Source CT00A map, PROT array row
      properties:
        tranId:
          type: string
          readOnly: true
        tranDate:
          type: string
          readOnly: true
        tranType:
          type: string
          readOnly: true
        formattedAmount:
          type: string
          readOnly: true
        merchantName:
          type: string
          readOnly: true
        tranStatus:
          type: string
          readOnly: true
          description: 88-level: P=Pending, O=Posted, R=Rejected

    # --- Admin TranType (DB2) ---
    TranTypeListResponse:
      allOf:
        - $ref: '#/components/schemas/CursorPageResponse'
        - type: object
          properties:
            rows:
              type: array
              items:
                $ref: '#/components/schemas/TranTypeRow'
            infoMessage:
              type: string
              description: Source INFOMSGO, PROT

    TranTypeRow:
      type: object
      properties:
        tranType:
          type: string
          readOnly: true
        description:
          type: string
        actionFlag:
          type: string
          enum: [U, D]
          description: U=Update, D=Delete (Source TRTSELI)

    # --- Admin Auth (IMS) ---
    AuthSummaryResponse:
      type: object
      properties:
        authRows:
          type: array
          items:
            $ref: '#/components/schemas/AuthRow'
        header:
          $ref: '#/components/schemas/AuthHeader'

    AuthRow:
      type: object
      properties:
        tranId:
          type: string
        processDate:
          type: string
        processTime:
          type: string
        authType:
          type: string
        approvalStatus:
          type: string
          enum: [APPROVED, DECLINED]
        matchStatus:
          type: string
        amount:
          type: string

    AuthHeader:
      type: object
      description: Source COPAU00.bms PROT header fields
      properties:
        acctId:
          type: string
        custName:
          type: string
        address1:
          type: string
        creditLimit:
          type: string
        approvedCount:
          type: integer
        declinedCount:
          type: integer
        approvedAmount:
          type: string
        declinedAmount:
          type: string

    # --- Pagination ---
    CursorPageResponse:
      type: object
      properties:
        pageNum:
          type: integer
        hasNextPage:
          type: boolean
        hasPrevPage:
          type: boolean
        nextCursor:
          type: string
          nullable: true
          description: PF8 key (source CommArea LAST-ID)
        prevCursor:
          type: string
          nullable: true
          description: PF7 key (source CommArea FIRST-ID)

security:
  - bearerAuth: []

# ============================
# PATHS
# ============================

paths:
  /auth/login:
    post:
      tags: [Authentication]
      summary: Login — COSGN00C equivalent
      description: Source COSGN0A map (COSGN00.bms). Validates USERID + PASSWORD against USRSEC VSAM.
      security: []
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/LoginRequest'
      responses:
        '200':
          description: Login successful (CICS XCTL to COMEN01C or COADM01C)
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/LoginResponse'
        '401':
          description: Invalid credentials (COBOL: IF SEC-USR-PWD ≠ input)
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ErrorResponse'

  /accounts/{acctId}:
    get:
      tags: [Accounts]
      summary: View Account — COACTVWC equivalent
      description: Source COACTVW.bms. CICS READ ACCTDATA + CUSTDATA + CARDAIX.
      parameters:
        - name: acctId
          in: path
          required: true
          schema:
            type: integer
          description: Source ACCTIDI, 11-digit numeric
      responses:
        '200':
          description: Account found
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/AccountViewResponse'
        '404':
          description: Account not found (CICS RESP=13 NOTFND)

    put:
      tags: [Accounts]
      summary: Update Account — COACTUPC equivalent
      description: Source COACTUP.bms CAUPA map. CICS READ UPDATE + REWRITE.
      parameters:
        - name: acctId
          in: path
          required: true
          schema: { type: integer }

  /accounts/{acctId}/cards:
    get:
      tags: [Cards]
      summary: Card List — COCRDLIC equivalent
      description: Source COCRDLI.bms. CICS STARTBR CARDAIX + READNEXT.

  /cards/{cardNum}:
    get:
      tags: [Cards]
      summary: Card Detail — COCRDSLC equivalent
      description: Source COCRDSL.bms.

    put:
      tags: [Cards]
      summary: Card Update — COCRDUPC equivalent (State Machine)
      description: |
        Source COCRDUP.bms. Implements 4-state FSM:
        NOT_FETCHED → SHOW_DETAILS → CHANGES_NOT_OK / CHANGES_OK → SAVED.
        PF5 = save, PF3 = exit, ENTER = search/validate.

  /transactions:
    get:
      tags: [Transactions]
      summary: Transaction List — COTRN00C equivalent
      description: Source COTRN00.bms. Cursor-based pagination.
      parameters:
        - name: acctId
          in: query
          schema: { type: integer }
        - name: cardNum
          in: query
          schema: { type: string }
        - name: dateStart
          in: query
          schema: { type: string, format: date }
        - name: dateEnd
          in: query
          schema: { type: string, format: date }
        - name: cursor
          in: query
          schema: { type: string }
        - name: direction
          in: query
          schema: { type: string, enum: [FORWARD, BACKWARD] }
    post:
      tags: [Transactions]
      summary: New Transaction — COTRN02C equivalent
      description: |
        Source COTRN02.bms. Creates transaction, updates TCATBALF.
        COBOL validation: card must be ACTIVE, amount > 0, ≤ available.

  /transactions/{tranId}:
    get:
      tags: [Transactions]
      summary: Transaction Detail — COTRN01C equivalent
      description: Source COTRN01.bms.

  /payments:
    post:
      tags: [Payments]
      summary: Make Payment — COBIL00C equivalent
      description: Source COBIL00.bms. Reduces balance, records transaction.

  /reports/transactions:
    get:
      tags: [Reports]
      summary: Transaction Report — CORPT00C equivalent
      description: Source CORPT00.bms.

  /admin/users:
    get:
      tags: [Admin - Users]
      summary: User List — COUSR00C equivalent
      description: Source COUSR00.bms. Admin only (SEC-USR-TYPE='A').
    post:
      tags: [Admin - Users]
      summary: Add User — COUSR01C equivalent

  /admin/users/{userId}:
    put:
      tags: [Admin - Users]
      summary: Update User — COUSR02C equivalent
    delete:
      tags: [Admin - Users]
      summary: Delete User — COUSR03C equivalent

  /admin/tran-types:
    get:
      tags: [Admin - Transaction Types]
      summary: TranType List (DB2) — COTRTLIC equivalent
      description: |
        Source COTRTLI.bms. DB2 cursor pagination.
        PF2=Add, ENTER=Search, PF7/PF8=Page, PF10=Confirm, 'U'=Update, 'D'=Delete.
    post:
      tags: [Admin - Transaction Types]
      summary: Add TranType — COTRTUPC equivalent

  /admin/tran-types/{typeCode}:
    put:
      tags: [Admin - Transaction Types]
      summary: Update TranType — COTRTUPC equivalent
    delete:
      tags: [Admin - Transaction Types]
      summary: Delete TranType (with FK check)

  /admin/auth-summary:
    get:
      tags: [Admin - Authorization]
      summary: Auth Summary (IMS) — COPAUS0C equivalent
      description: |
        Source COPAU00.bms. IMS DB GNP data → relational query.
        PF7/PF8 page, 'S' select → detail.

  /admin/auth-detail/{authKey}:
    get:
      tags: [Admin - Authorization]
      summary: Auth Detail (IMS) — COPAUS1C equivalent

  /batch/export:
    post:
      tags: [Batch]
      summary: Data Export — CBEXPORT equivalent
      description: Source CBEXPORT.cbl + CBEXPORT.jcl.

  /batch/import:
    post:
      tags: [Batch]
      summary: Data Import — CBIMPORT equivalent
```

## Execution Steps

### Step 1: Collect All Endpoints from Phase 8

From `rest-api-specification.md` or Phase 8 deliverables, extract every endpoint with method, path, request, response.

### Step 2: Generate Schema Components

Map each Response DTO to OpenAPI schema. Map each Request DTO to OpenAPI schema with validation constraints.

### Step 3: Generate Path Items

For every BMS screen, generate get/post/put/delete as appropriate.

### Step 4: Add Source References

Every schema property and endpoint MUST include COBOL source reference in description.

### Step 5: Export to YAML

Write `08-deliverables/openapi-spec.yaml`.

## Quality Gate

- [ ] All 24 endpoints defined in Phase 8 are in the spec
- [ ] All Request DTO schemas have validation constraints
- [ ] All Response DTO schemas have readOnly fields
- [ ] Pagination endpoints use cursor-based parameters
- [ ] COBOL source references in every endpoint description
- [ ] Security scheme defined (bearerAuth JWT)
- [ ] Spec validates against OpenAPI 3.0 schema
- [ ] TAGS group endpoints by CICS transaction ID
