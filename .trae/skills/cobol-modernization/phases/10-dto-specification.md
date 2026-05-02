# Phase 8a: DTO Specification & Validation Generation

> **DEPENDS ON:** Phase 3 (BMS Analysis) + Phase 4 (COPYBOOK) + Phase 5 (Program Logic)  
> **OUTPUT:** `08-deliverables/dto-specification.md` (standalone or merged with Phase 8)

## Objective

Generate complete, compilable DTO (Data Transfer Object) classes for every BMS screen and every cross-service data exchange. This phase bridges the gap between BMS field analysis and Java API contracts.

## Why This Phase Is Critical

The DTO layer is the **contract between front-end and back-end**. Without precise DTO specifications:
- Bean Validation annotations cannot be generated from COBOL IF rules
- Front-end developers don't know field formats and constraints
- AI code generation produces incomplete/inaccurate code
- Error messages lack proper mapping from COBOL error text

## DTO Generation Rules

### Rule 1: One DTO Pair Per BMS Map

Every BMS map generates exactly:

| DTO Type | Source | Contains |
|----------|--------|----------|
| `{ScreenName}Request` | ALL UNPROT fields from .bms | User input fields + Bean Validation |
| `{ScreenName}Response` | ALL PROT fields + CommArea fields | Display data + pagination metadata |

### Rule 2: Field Mapping Convention

```
BMS field: USERIDI  (suffix I = input)
  → Java field: userId  (camelCase, no suffix)
  → Bean Validation: @NotBlank @Size(max=8)

BMS field: ERRMSGO  (suffix O = output)
  → Java field: errorMsg  (camelCase, no suffix)
  → No validation (output only)

BMS field: SEL0001I  (input with index)
  → Java field: selectedRow1
  → Bean Validation: @Size(max=1)
```

### Rule 3: Validation Extraction

Extract validation rules from Phase 5 analysis:

| COBOL IF Condition | Bean Validation | HTTP Status |
|--------------------|----------------|-------------|
| `IF [FIELD] = SPACES` | `@NotBlank(message="...")` | 400 |
| `IF [FIELD] NOT NUMERIC` | `@Pattern(regexp="^\\d+$")` | 400 |
| `IF [FIELD] > 0` | `@Positive` / `@DecimalMin("0.01")` | 400 |
| `IF [FIELD] LENGTH > N` | `@Size(max=N)` | 400 |
| `IF NOT [88-FLAG]` | `@AssertTrue` / custom validator | 400 |
| `RESP ≠ 0 (NOTFND)` | Service-level (→ 404) | 404 |
| `RESP ≠ 0 (DUPKEY)` | Service-level (→ 409) | 409 |

**ERROR MESSAGE EXTRACTION:** Every `IF [FIELD] = SPACES` check in COBOL MUST have a corresponding error message string. Extract this from:
1. The SEND MAP statement that sets ERRMSGO
2. The MOVE statement before the IF check
3. The CSMSG01Y.cpy common messages copybook

## DTO Classification by Screen Type

### Type A: Simple Display Screen (e.g., COACTVWC — Account View)

```java
// Source: COACTVW.bms, COACTVWA map → COACTVWC.cbl
// Screen Type: Search-Then-Display

@Data @Builder @NoArgsConstructor @AllArgsConstructor
public class AccountViewRequest {
    // Source: ACCTIDI, BMS UNPROT, X(11), row 10 col 30
    // COBOL: IF ACCTIDI NOT NUMERIC → "Must be numeric"
    // COBOL: IF ACCTIDI = SPACES → "Account ID required"
    @NotBlank(message = "Account ID is required")
    @Pattern(regexp = "^\\d{11}$", message = "Account ID must be 11 digits")
    private String acctId;
}

@Data @Builder @NoArgsConstructor @AllArgsConstructor
public class AccountViewResponse {
    // Source: COACTVW.bms + CommArea COCOM01Y.cpy
    private String errorMessage;
    private String title;
    private String curDate;
    private AccountInfo accountInfo;
    private CustomerInfo customerInfo;
    private List<CardSummary> cards;
}

@Data @Builder
public class AccountInfo {
    private String acctId;           // ACCTIDO, PROT
    private String status;           // STATUSO, PROT
    private String currBal;          // CURRBALO, PROT, formatted
    private String creditLimit;      // CREDLIMO, PROT, formatted
    private String cashCreditLimit;  // CASHLIMO, PROT, formatted
    private String lastActivity;     // LASTACTV, PROT
    private String interestRate;     // INTRATEO, PROT, formatted
    private String billingCycle;     // BILCYCLO, PROT
}

@Data @Builder
public class CardSummary {
    private String cardNum;          // CARDNUMO, PROT
    private String cardStatus;       // CARDSTSO, PROT
    private String primaryFlag;      // CARDPRIMO, PROT
    private String nameOnCard;       // CARDNAMEO, PROT
    private String expDate;          // CARDEXPO, PROT
}
```

### Type B: Update Screen with State Machine (e.g., COCRDUPC — Card Update)

```java
// Source: COCRDUP.bms, CCRDUPA map → COCRDUPC.cbl
// Screen Type: Search-Then-Update / State Machine
// States: NOT_FETCHED → SHOW_DETAILS → CHANGES_NOT_OK/CHANGES_OK → SAVED

@Data @Builder @NoArgsConstructor @AllArgsConstructor
public class CardUpdateRequest {
    // Source: CARDNUMI, BMS UNPROT, X(16)
    // Used in NOT_FETCHED state (search by card number)
    @Size(max = 16, message = "Card number must be 16 digits or less")
    private String cardNum;

    // Source: CARDSTAI, BMS UNPROT, X(1)
    // COBOL: IF CARDSTAI NOT A/I/L → "Invalid status"
    @Pattern(regexp = "^[AIL]$", message = "Status must be A (Active), I (Inactive), or L (Lost)")
    private String cardStatus;

    // Source: CARDNAMEI, BMS UNPROT, X(30)
    // COBOL: IF CARDNAMEI = SPACES → "Name cannot be blank"
    private String nameOnCard;

    // Source: CARDPRIMI, BMS UNPROT, X(1)
    // COBOL: IF CARDPRIMI NOT Y/N → "Primary flag must be Y or N"
    @Pattern(regexp = "^[YN]$", message = "Primary flag must be Y or N")
    private String primaryFlag;

    // Source: CCARD-AID-PFK05 (CommArea COCOM01Y) — "Save" action
    private String action;  // "SEARCH" / "SAVE" / "CANCEL"
}

@Data @Builder @NoArgsConstructor @AllArgsConstructor
public class CardUpdateResponse {
    private String errorMessage;
    private String title;
    private String state;                // current FSM state
    private CardDetail cardDetail;       // populated in SHOW_DETAILS
    private List<String> fieldErrors;    // populated in CHANGES_NOT_OK
    private String successMessage;       // populated in SAVED
}
```

### Type C: Paginated List Screen (e.g., COTRN00C — Transaction List)

```java
// Source: COTRN00.bms, CT00A map → COTRN00C.cbl
// Screen Type: List-Pagination

@Data @Builder @NoArgsConstructor @AllArgsConstructor
public class TransactionListRequest {
    // Filters
    @Size(max = 11)
    private String acctId;

    @Size(max = 16)
    private String cardNum;

    private String dateStart;    // MM/DD/YYYY format
    private String dateEnd;

    // Pagination
    private String cursor;       // forward: lastId / backward: firstId
    private String direction;    // "FORWARD" (PF8) / "BACKWARD" (PF7)
    private String action;       // "SEARCH" / "NEXT" / "PREV" / "CANCEL"
}

@Data @Builder @NoArgsConstructor @AllArgsConstructor
public class TransactionListResponse {
    private String errorMessage;
    private String title;

    // Paginated items
    private List<TransactionSummary> items;

    // Cursor navigation (from CommArea)
    private Integer pageNum;
    private Boolean hasNextPage;
    private Boolean hasPrevPage;
    private String nextCursor;
    private String prevCursor;
    private Integer totalCount;     // if available from batch
}

@Data @Builder
public class TransactionSummary {
    private String tranId;
    private String tranDate;
    private String tranTime;
    private String tranType;
    private String tranCatCd;
    private String formattedAmount;
    private String merchantName;
    private String tranStatus;       // P/Pending, O/Posted, R/Rejected
}
```

### Type D: DB2 Cursor Screen (e.g., COTRTLIC — TranType List)

```java
// Source: COTRTLI.bms, CTRTLIA map → COTRTLIC.cbl
// Screen Type: List-Pagination with DB2 Cursor

@Data @Builder @NoArgsConstructor @AllArgsConstructor
public class TranTypeListRequest {
    // Source: TRTYPEI, UNPROT, X(2)
    @Size(max = 2)
    private String typeCode;

    // Source: TRDESCI, UNPROT, X(50)
    @Size(max = 50)
    private String description;

    // Source: TRTSELI (row N), UNPROT, X(1) — action flag 'U'/'D'
    private String actionFlag;

    // Source: TRTYPDI (row N), UNPROT, X(50) — editable description
    private String newDescription;

    // Pagination (DB2 cursor)
    private String direction;    // "FORWARD" / "BACKWARD"
    private String cursorKey;    // last FETCHed TR_TYPE for resume

    // CICS-equivalent PF keys
    private String command;      // "SEARCH"/"PAGE_UP"/"PAGE_DOWN"/"CONFIRM"/"ADD"
}

@Data @Builder @NoArgsConstructor @AllArgsConstructor
public class TranTypeListResponse {
    private String errorMessage;
    private String infoMessage;         // INFOMSGO, PROT
    private List<TranTypeRow> items;    // 7 rows max
    private Integer pageNum;            // PAGENOO
    private Boolean hasNextPage;
    private Boolean hasPrevPage;
    private String nextCursorKey;
    private String prevCursorKey;
    private Boolean isDeleteConfirm;    // highlight state for D
}

@Data @Builder
public class TranTypeRow {
    private String tranType;
    private String description;
    private String actionFlag;     // U/D/BLANK
    private Boolean editable;      // when flagged U
    private Boolean deleteWarning; // when flagged D + PF10 not yet pressed
}
```

## Paginated Response Patterns

### Cursor-Based Pagination (CICS STARTBR/READNEXT Pattern)

```java
// Source: CICS STARTBR → READNEXT×N → ENDBR pattern
// Used by: COTRN00C, COCRDLIC, COUSR00C, COPAUS0C, COTRTLIC

@Data
public class CursorPageResponse<T> {
    private List<T> items;
    private Integer pageNum;
    private Boolean hasNextPage;
    private Boolean hasPrevPage;
    private String nextCursor;
    private String prevCursor;
    private Integer totalCount;

    public static <T> CursorPageResponse<T> of(
            List<T> allItems, int pageSize, String lastId, String firstId, int pageNum) {

        boolean hasNext = allItems.size() > pageSize;
        boolean hasPrev = pageNum > 1;

        List<T> pageItems = hasNext
            ? allItems.subList(0, pageSize)
            : allItems;

        return CursorPageResponse.<T>builder()
            .items(pageItems)
            .pageNum(pageNum)
            .hasNextPage(hasNext)
            .hasPrevPage(hasPrev)
            .nextCursor(hasNext ? extractId(pageItems.get(pageItems.size() - 1)) : null)
            .prevCursor(hasPrev ? firstId : null)
            .totalCount(null)  // set if COUNT(*) available
            .build();
    }

    private static <T> String extractId(T item) {
        // Use reflection or getId() interface
        return item.toString();  // override per entity
    }
}
```

### File-Driven Batch Export DTO

```java
// Source: CBEXPORT.cbl + CVEXPORT.cpy
// COBOL: WRITE export-record FROM EXPORT-DATA-LAYOUT

@Data @Builder @NoArgsConstructor @AllArgsConstructor
public class ExportRequest {
    @NotBlank
    private String exportType;       // ACCT/CARD/CUST/TRAN/ALL
    private String dateStart;
    private String dateEnd;
}

@Data @Builder @NoArgsConstructor @AllArgsConstructor
public class ExportResponse {
    private String jobId;
    private String status;           // QUEUED/RUNNING/COMPLETED/FAILED
    private String downloadUrl;      // pre-signed S3 URL
    private LocalDateTime completedAt;
}
```

## Cross-Service DTOs

For service-to-service communication, define shared DTOs:

```java
// Shared between: account-service ↔ card-service ↔ transaction-service

@Data @Builder @NoArgsConstructor @AllArgsConstructor
public class AccountBalanceCheckResponse {
    private Long acctId;
    private BigDecimal currentBalance;
    private BigDecimal creditLimit;
    private boolean active;
    private boolean hasAvailableCredit;
}

@Data @Builder @NoArgsConstructor @AllArgsConstructor
public class CardValidationResponse {
    private String cardNum;
    private Long acctId;
    private Long custId;
    private boolean active;
    private boolean withinExpiry;
    private String cardholderName;
}
```

## Validation Annotation Mapping Reference

| BMS DFHMDF Attribute | COBOL IF Check | Bean Validation |
|---------------------|---------------|----------------|
| UNPROT, LENGTH=8 | `IF FIELD = SPACES` | `@NotBlank` + `@Size(max=8)` |
| UNPROT, LENGTH=16 | `IF FIELD NOT NUMERIC` | `@Pattern(regexp="^\\d+$")` + `@Size(max=16)` |
| UNPROT, PIC S9(9)V99 | `IF FIELD ≤ 0` | `@NotNull` + `@DecimalMin("0.01")` |
| UNPROT, PIC X(4) date | `IF FIELD NOT VALID-DATE` | `@Pattern(regexp="^(0[1-9]|1[0-2])$")` (MMYY) |
| UNPROT (dropdown) | `IF FIELD NOT IN (A,I,L)` | `@Pattern(regexp="^[AIL]$")` |
| UNPROT (email) | — (COBOL no email validation) | `@Email` (NEW — cloud-era addition) |
| UNPROT (phone) | — (COBOL no phone validation) | `@Pattern(regexp="^\\d{3}-\\d{3}-\\d{4}$")` (NEW) |

## DTO Mapping from COPYBOOK Fields

| COPYBOOK Source | BMS Map Field | DTO Field | JPA Entity |
|-----------------|-------------|-----------|-----------|
| CVACT01Y.ACCT-ID | ACCTIDI (COACTVW) | AccountViewRequest.acctId | Account.acctId |
| CVACT02Y.CARD-NUM | CARDNUMI (COCRDSL) | CardDetailRequest.cardNum | Card.cardNum |
| CVCUS01Y.CUST-NAME | CNAMEO (COSGN0A) | AccountViewResponse.customerInfo.name | Customer.firstName + lastName |
| COCOM01Y.CDEMO-CT00-PAGE-NUM | CT00A pagination | TransactionListResponse.pageNum | — (app state) |

## Execution Steps

### Step 1: Inventory ALL BMS UNPROT Fields

From Phase 3 bms-map-analysis.md, extract ALL fields with attrib=UNPROT.

### Step 2: Extract Validation Rules

For each UNPROT field, find the matching COBOL IF check from Phase 5 program-logic-analysis.md.

### Step 3: Generate Request DTOs

Create one Request class per map with Bean Validation annotations.

### Step 4: Generate Response DTOs

Create one Response class per map with PROT field mappings and pagination metadata.

### Step 5: Generate Shared DTOs

Create cross-service DTOs for service-to-service communication.

### Step 6: Export

Write `08-deliverables/dto-specification.md` with ALL generated DTO classes.

## Quality Gate

- [ ] Every BMS map has Request + Response DTO pair
- [ ] Every UNPROT field has corresponding Bean Validation annotation
- [ ] Every validation annotation has error message matching COBOL error text
- [ ] Pagination screens have CursorPageResponse wrapper
- [ ] DB2 cursor screens have cursorKey fields
- [ ] State machine screens have state field
- [ ] All DTO classes compile (valid Java syntax)
- [ ] All DTOs have `// Source:` reference comments
- [ ] Cross-validation check 42 (BMS-DTO) passes
