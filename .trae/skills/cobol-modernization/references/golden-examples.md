# Golden Code Generation Examples (Production-Grade)

This document provides battle-tested, complete code examples for COBOL→Java migration.
These represent the **minimum quality standard** for all AI-generated migration code.

---

## Example 1: CICS Login → Spring Security + REST Controller

### COBOL Pattern
```cobol
PROCEDURE DIVISION.
MAIN-PARA.
    IF EIBCALEN = 0
        MOVE LOW-VALUES TO MAP-OUTPUT
        PERFORM SEND-LOGIN-SCREEN
    ELSE
        EVALUATE EIBAID
            WHEN DFHENTER
                PERFORM PROCESS-ENTER-KEY
            WHEN DFHPF3
                PERFORM SEND-THANK-YOU-SCREEN
        END-EVALUATE
    END-IF.

PROCESS-ENTER-KEY.
    EXEC CICS RECEIVE MAP('LOGINMAP') MAPSET('LOGINMS') END-EXEC.
    IF USER-INPUT-ID = SPACES
        MOVE 'Please enter User ID ...' TO ERROR-MSG
        PERFORM SEND-LOGIN-SCREEN
    END-IF.
    PERFORM READ-USER-FILE.
    IF USER-PASSWORD = INPUT-PASSWORD
        IF USER-TYPE = 'ADMIN'
            EXEC CICS XCTL PROGRAM('ADMIN-MENU') COMMAREA(...) END-EXEC
        ELSE
            EXEC CICS XCTL PROGRAM('USER-MENU') COMMAREA(...) END-EXEC
        END-IF
    ELSE
        MOVE 'Wrong Password. Try again ...' TO ERROR-MSG
        PERFORM SEND-LOGIN-SCREEN
    END-IF.
```

### Java Equivalent

```java
// AuthController.java
// Source: [cics-login-program].cbl, PROCEDURE DIVISION

@RestController
@RequestMapping("/api/v1/auth")
@Tag(name = "Authentication", description = "Login and session management")
public class AuthController {

    private final AuthenticationService authService;

    public AuthController(AuthenticationService authService) {
        this.authService = authService;
    }

    // Source: EIBCALEN = 0 → first-time screen display
    @GetMapping("/login")
    @Operation(summary = "Get login page metadata")
    public ResponseEntity<LoginPageResponse> getLoginPage() {
        return ResponseEntity.ok(LoginPageResponse.builder()
            .title("Application - Sign On")
            .programName("[source-program-id]")
            .build());
    }

    // Source: DFHENTER → PROCESS-ENTER-KEY → CICS RECEIVE MAP + READ-USER-FILE + XCTL
    @PostMapping("/login")
    @Operation(summary = "Authenticate user")
    public ResponseEntity<AuthResponse> login(@Valid @RequestBody LoginRequest request) {

        // Source: IF USER-INPUT-ID = SPACES, line [N]
        if (request.getUserId() == null || request.getUserId().isBlank()) {
            throw new ValidationException("Please enter User ID ...");
        }

        // Source: READ-USER-FILE → repository.findById(), line [N]
        // Source: USER-PASSWORD comparison → passwordEncoder.matches(), line [N]
        AuthResult result = authService.authenticate(
            request.getUserId().toUpperCase(),   // Source: FUNCTION UPPER-CASE
            request.getPassword().toUpperCase()
        );

        // Source: IF USER-TYPE = 'ADMIN' → XCTL ADMIN-MENU, line [N]
        // Source: ELSE → XCTL USER-MENU, line [N]
        return ResponseEntity.ok(AuthResponse.builder()
            .token(result.getJwtToken())
            .redirectUrl(result.isAdmin() ? "/admin/menu" : "/user/menu")
            .userType(result.isAdmin() ? "ADMIN" : "USER")
            .message(result.isSuccess() ? "Login successful" : "Wrong Password")
            .build());
    }
}

// AuthenticationService.java
// Source: login program PROCEDURE DIVISION business logic

@Service
@Transactional
public class AuthenticationService {

    private final UserSecurityRepository userSecurityRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtTokenProvider jwtTokenProvider;

    public AuthenticationService(
            UserSecurityRepository userSecurityRepository,
            PasswordEncoder passwordEncoder,
            JwtTokenProvider jwtTokenProvider) {
        this.userSecurityRepository = userSecurityRepository;
        this.passwordEncoder = passwordEncoder;
        this.jwtTokenProvider = jwtTokenProvider;
    }

    // Source: READ-USER-FILE paragraph, lines [N]-[M]
    // Source: EVALUATE WS-RESP-CD → WHEN 0 (found), WHEN 13 (not found)
    public AuthResult authenticate(String userId, String password) {
        UserSecurity user = userSecurityRepository
            .findById(userId)
            .orElseThrow(() -> new AuthenticationException("User not found. Try again ..."));

        // Source: IF USER-PASSWORD = INPUT-PASSWORD, line [N]
        if (!passwordEncoder.matches(password, user.getPasswordHash())) {
            // Migrate plain-text passwords on first login
            if (user.getPasswordHash().equals(password)) {
                user.setPasswordHash(passwordEncoder.encode(password));
                userSecurityRepository.save(user);
            } else {
                throw new AuthenticationException("Wrong Password. Try again ...");
            }
        }

        // Source: IF USER-TYPE = 'ADMIN' → different routing, line [N]
        String role = user.getUserType().equals("A") ? "ROLE_ADMIN" : "ROLE_USER";
        String token = jwtTokenProvider.createToken(userId, role);

        return new AuthResult(token, "A".equals(user.getUserType()), true);
    }
}

// LoginRequest.java
// Source: BMS UNPROT fields (USERID + PASSWD), MAP name: LOGINMAP

@Data @Builder @NoArgsConstructor @AllArgsConstructor
public class LoginRequest {
    @NotBlank(message = "User ID is required")
    @Size(min = 1, max = 8, message = "User ID must be 1-8 characters")
    private String userId;   // Source: USER-INPUT-ID (PIC X(08))

    @NotBlank(message = "Password is required")
    @Size(min = 1, max = 8, message = "Password must be 1-8 characters")
    private String password; // Source: INPUT-PASSWORD (PIC X(08))
}

// AuthResponse.java
// Source: BMS PROT fields + XCTL routing

@Data @Builder @NoArgsConstructor @AllArgsConstructor
public class AuthResponse {
    private String token;       // Source: CICS commarea session
    private String redirectUrl; // Source: XCTL PROGRAM destination
    private String userType;    // Source: USER-TYPE
    private String message;     // Source: ERROR-MSG
}
```

### Traceability Table

| COBOL Element | Java Equivalent |
|--------------|----------------|
| PROCEDURE DIVISION MAIN-PARA | Controller endpoints (one per PF key) |
| EIBCALEN = 0 check | GET endpoint (initialize screen) |
| DFHENTER → PROCESS-ENTER-KEY | POST endpoint (process form) |
| CICS RECEIVE MAP | @Valid @RequestBody |
| FIELD = SPACES | @NotBlank |
| FUNCTION UPPER-CASE | String.toUpperCase() |
| READ-USER-FILE | repository.findById() → Optional |
| PASSWORD comparison | passwordEncoder.matches() |
| CICS XCTL (admin) | redirectUrl="/admin/menu" |
| Wrong Password | AuthenticationException → HTTP 401 |
| User not found (RESP=13) | orElseThrow() → HTTP 404 |

---

## Example 2: VSAM File I/O → JPA Repository + Transactional Service

### COBOL Pattern
```cobol
PROCEDURE DIVISION.
READ-ACCT-FILE.
    EXEC CICS READ DATASET(WS-ACCT-FILE) INTO(ACCOUNT-RECORD)
         RIDFLD(ACCOUNT-ID) UPDATE RESP(WS-RESP-CD) END-EXEC.
    EVALUATE WS-RESP-CD
        WHEN DFHRESP(NORMAL)    CONTINUE
        WHEN DFHRESP(NOTFND)    MOVE 'Account NOT found...' TO WS-MSG
    END-EVALUATE.

    IF ACCOUNT-BALANCE <= ZEROS
        MOVE 'Nothing to pay...' TO WS-MSG
    END-IF.

    MOVE HIGH-VALUES TO TRAN-ID
    PERFORM STARTBR-TRANSACT-FILE
    PERFORM READPREV-TRANSACT-FILE
    MOVE TRAN-ID TO WS-TRAN-ID-NUM
    ADD 1 TO WS-TRAN-ID-NUM

    MOVE WS-TRAN-ID-NUM   TO TRAN-ID
    MOVE ACCOUNT-BALANCE  TO TRAN-AMOUNT
    PERFORM WRITE-TRANSACT-FILE

    COMPUTE ACCOUNT-BALANCE = ACCOUNT-BALANCE - TRAN-AMOUNT
    PERFORM UPDATE-ACCT-FILE.
```

### Java Equivalent (Concurrency-Safe)

```java
@Service
@Transactional
@Slf4j
public class PaymentService {

    private final AccountRepository accountRepository;
    private final TransactionRepository transactionRepository;
    private final CardXrefRepository cardXrefRepository;

    public PaymentService(
            AccountRepository accountRepository,
            TransactionRepository transactionRepository,
            CardXrefRepository cardXrefRepository) {
        this.accountRepository = accountRepository;
        this.transactionRepository = transactionRepository;
        this.cardXrefRepository = cardXrefRepository;
    }

    // Source: READ-ACCT-FILE with UPDATE lock, lines [N]-[M]
    // Source: READPREV-TRANSACT-FILE for ID, lines [N]-[M]
    // Source: WRITE-TRANSACT-FILE + UPDATE-ACCT-FILE, lines [N]-[M]
    // Source: COMPUTE ACCOUNT-BALANCE = ACCOUNT-BALANCE - TRAN-AMOUNT, line [N]
    public PaymentResponse processPayment(String accountId, boolean confirmed) {

        // Source: ACTIDINI = SPACES validation, line [N]
        if (accountId == null || accountId.isBlank()) {
            throw new ValidationException("Account ID cannot be empty...");
        }

        // Source: EVALUATE CONFIRM INPUT, lines [N]-[M]
        if (!confirmed) {
            return PaymentResponse.builder()
                .message("Confirm to make a payment...")
                .requiresConfirmation(true)
                .build();
        }

        // Source: READ-ACCT-FILE with UPDATE
        // CRITICAL: @Lock(PESSIMISTIC_WRITE) = CICS READ UPDATE locking
        // Source: lines [N]-[M]
        Account account = accountRepository.findByIdForUpdate(Long.parseLong(accountId))
            .orElseThrow(() -> new NotFoundException("Account NOT found..."));

        // Source: IF ACCOUNT-BALANCE <= ZEROS, lines [N]-[M]
        if (account.getBalance().compareTo(BigDecimal.ZERO) <= 0) {
            throw new BusinessException("Nothing to pay...");
        }

        // Source: READ-CROSS-REF-FILE, lines [N]-[M]
        CardXref cardXref = cardXrefRepository.findByAcctId(Long.parseLong(accountId))
            .orElseThrow(() -> new NotFoundException("Account NOT found..."));

        // Source: STARTBR + READPREV (MAX+1 pattern), lines [N]-[M]
        // CRITICAL: Use SEQUENCE instead of MAX+1 for concurrency safety
        Long newTranId = transactionRepository.nextTransactionId();

        // Source: MOVE fields to TRAN-RECORD, lines [N]-[M]
        Transaction transaction = Transaction.builder()
            .tranId(newTranId)
            .tranTypeCode("02")
            .tranCategoryCode(2)
            .tranSource("POS TERM")
            .tranDesc("PAYMENT - ONLINE")
            .tranAmount(account.getBalance())
            .cardNum(cardXref.getCardNum())
            .merchantId(999999999L)
            .merchantName("PAYMENT")
            .build();

        // Source: WRITE-TRANSACT-FILE, lines [N]-[M]
        // Source: DUPKEY check → catch DataIntegrityViolationException
        try {
            transactionRepository.save(transaction);
        } catch (DataIntegrityViolationException e) {
            throw new BusinessException("Transaction ID already exists...");
        }

        // Source: COMPUTE ACCOUNT-BALANCE = ACCOUNT-BALANCE - TRAN-AMOUNT, line [N]
        BigDecimal newBalance = account.getBalance().subtract(transaction.getTranAmount());

        // Source: UPDATE-ACCT-FILE (REWRITE), lines [N]-[M]
        account.setBalance(newBalance);
        accountRepository.save(account);

        log.info("Payment successful: accountId={}, tranId={}, amount={}",
            accountId, newTranId, transaction.getTranAmount());

        return PaymentResponse.builder()
            .message("Payment successful. Your Transaction ID is " + newTranId + ".")
            .transactionId(newTranId)
            .newBalance(newBalance)
            .build();
    }
}

// AccountRepository.java
@Repository
public interface AccountRepository extends JpaRepository<Account, Long> {

    // Source: CICS READ with UPDATE → PESSIMISTIC_WRITE, line [N]
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT a FROM Account a WHERE a.acctId = :acctId")
    Optional<Account> findByIdForUpdate(@Param("acctId") Long acctId);

    // Source: Sequential browse (STARTBR + READNEXT), lines [N]-[M]
    List<Account> findByAcctIdBetween(Long startId, Long endId, Pageable pageable);
}

// TransactionRepository.java
@Repository
public interface TransactionRepository extends JpaRepository<Transaction, Long> {

    // Source: STARTBR + READPREV (MAX+1), lines [N]-[M]
    // CRITICAL: Replace with SEQUENCE for concurrency safety
    @Query(value = "SELECT NEXTVAL('tran_id_seq')", nativeQuery = true)
    Long nextTransactionId();

    // Source: CICS STARTBR + READNEXT browse, lines [N]-[M]
    List<Transaction> findByCardNum(String cardNum, Pageable pageable);
}
```

### Concurrency Evolution

| COBOL Pattern | COBOL (Safe) | Naive Java (RACE!) | Production Java (Safe) |
|--------------|-------------|-------------------|----------------------|
| MAX+1 ID | Single-thread CICS | `findMaxId() + 1` | SEQUENCE / Snowflake |
| READ UPDATE + REWRITE | Implicit CICS lock | Simple save() | @Lock(PESSIMISTIC_WRITE) |
| SYNCPOINT | CICS unit of work | Individual saves | @Transactional + @Version |
| Working-Storage | Per-task instance | Singleton field | Method-local variables |

---

## COMP-3 Unpack Utility

```java
/**
 * COMP-3 (Packed Decimal) conversion utility.
 * This is the #1 failure point in COBOL-to-Java migrations.
 */
public final class Comp3Converter {

    private Comp3Converter() {}

    /**
     * Unpack COMP-3 bytes to BigDecimal.
     * Each byte stores 2 nibbles. Last nibble is sign: 0xC=pos, 0xD=neg, 0xF=unsigned.
     */
    public static BigDecimal unpack(byte[] bytes, int scale) {
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < bytes.length; i++) {
            int b = bytes[i] & 0xFF;
            int high = (b >> 4) & 0x0F;
            int low = b & 0x0F;

            if (i < bytes.length - 1) {
                validateNibble(high, "high nibble at byte " + i);
                validateNibble(low, "low nibble at byte " + i);
                sb.append((char) ('0' + high));
                sb.append((char) ('0' + low));
            } else {
                validateNibble(high, "sign nibble high at byte " + i);
                sb.append((char) ('0' + high));
                if (low == 0x0D) {
                    sb.insert(0, '-');
                } else if (low != 0x0C && low != 0x0F) {
                    throw new IllegalArgumentException("Invalid sign nibble: " + low);
                }
            }
        }
        return new BigDecimal(sb.toString()).movePointLeft(scale).stripTrailingZeros();
    }

    private static void validateNibble(int nibble, String location) {
        if (nibble < 0 || nibble > 9) {
            throw new IllegalArgumentException("Invalid digit nibble: " + nibble + " at " + location);
        }
    }

    public static byte[] pack(BigDecimal value, int byteCount) {
        String digits = value.abs().toPlainString().replace(".", "");
        byte[] result = new byte[byteCount];
        boolean negative = value.signum() < 0;
        int digitIdx = digits.length() - 1;

        for (int i = byteCount - 1; i >= 0; i--) {
            int low = (digitIdx >= 0) ? digits.charAt(digitIdx--) - '0' : 0;
            int high = (digitIdx >= 0) ? digits.charAt(digitIdx--) - '0' : 0;
            if (i == byteCount - 1) {
                result[i] = (byte) ((high << 4) | (negative ? 0x0D : 0x0C));
            } else {
                result[i] = (byte) ((high << 4) | low);
            }
        }
        return result;
    }
}
```

## Hex Dump Examples for Verification

```
COMP-3 S9(10)V99, value 1234567890.12 → 0x01 0x23 0x45 0x67 0x89 0x01 0x2C (7 bytes)
COMP-3 S9(7)V99,  value 12345.67       → 0x01 0x23 0x45 0x67 0xC  (5 bytes)
COMP-3 S9(5)V99,  value -123.45        → 0x01 0x23 0x4D          (3 bytes, D=negative)
COMP 9(4),        value 12345           → 0x00 0x00 0x30 0x39     (4 bytes, big-endian)
COMP S9(9),       value -987654321      → 0xC6 0x9B 0x14 0x1F     (4 bytes, two's complement)
```

## Entity Pattern (Production-Ready)

```java
@Entity
@Table(name = "account", indexes = {
    @Index(name = "idx_account_customer", columnList = "customer_id"),
    @Index(name = "idx_account_status", columnList = "account_status")
})
@Data @Builder @NoArgsConstructor @AllArgsConstructor
public class Account {

    @Id
    @Column(name = "account_id", length = 11, nullable = false)
    @Pattern(regexp = "\\d{11}")
    private String accountId;              // Source: ACCT-ID PIC 9(11), CVACT01Y.cpy line [N]

    @Column(name = "customer_id", length = 11, nullable = false)
    private String customerId;             // Source: CUST-ID PIC 9(11), line [N]

    @Column(name = "account_status", length = 1)
    @Pattern(regexp = "[AIO]")
    private String accountStatus;          // Source: ACCT-STATUS PIC X(01), line [N]
                                           // 88: ACTIVE='A', INACTIVE='I', CLOSED='O'

    @Column(name = "current_balance", precision = 17, scale = 2)
    private BigDecimal currentBalance;     // Source: COMP-3 S9(15)V99 → DECIMAL(17,2), line [N]

    @Column(name = "credit_limit", precision = 13, scale = 2)
    private BigDecimal creditLimit;        // Source: COMP-3 S9(11)V99 → DECIMAL(13,2), line [N]

    @Column(name = "open_date")
    private LocalDate openDate;            // Source: PIC X(10) YYYY-MM-DD, line [N]

    @Version
    @Column(name = "version")
    private Long version;                  // Optimistic locking (was CICS READ UPDATE)

    @PrePersist @PreUpdate
    public void prePersist() {
        this.lastUpdated = LocalDateTime.now();
    }

    // Business methods
    public BigDecimal getAvailableCredit() {
        if (creditLimit == null || currentBalance == null) return BigDecimal.ZERO;
        return creditLimit.subtract(currentBalance);
    }

    public boolean isActive() { return "A".equals(accountStatus); }
    public boolean isInactive() { return "I".equals(accountStatus); }
    public boolean isClosed() { return "O".equals(accountStatus); }
}
```

## Example 3: CICS Browsing (STARTBR/READNEXT/READPREV) → Cursor-Based Pagination

### COBOL Pattern
```cobol
PROCESS-PAGE-FORWARD.
    MOVE WS-TRNID-LAST TO TRAN-ID.
    EXEC CICS STARTBR DATASET('TRANSACT') RIDFLD(TRAN-ID)
         KEYLENGTH(16) GTEQ RESP(WS-RESP-CD) END-EXEC.

    EXEC CICS READNEXT DATASET('TRANSACT') INTO(TRAN-RECORD)
         RIDFLD(TRAN-ID) RESP(WS-RESP-CD) END-EXEC.

    IF WS-RESP-CD = DFHRESP(NORMAL)
        PERFORM VARYING WS-IDX FROM 1 BY 1
            UNTIL WS-IDX > 10 OR WS-RESP-CD NOT = DFHRESP(NORMAL)
            DISPLAY TRAN-ID TRAN-DESC TRAN-AMT
            EXEC CICS READNEXT DATASET('TRANSACT') INTO(TRAN-RECORD)
                 RIDFLD(TRAN-ID) RESP(WS-RESP-CD) END-EXEC
        END-PERFORM
    END-IF.

    IF WS-RESP-CD = DFHRESP(ENDFILE)
        MOVE 'N' TO WS-NEXT-PAGE-FLG
    END-IF.

PROCESS-PAGE-BACKWARD.
    MOVE WS-TRNID-FIRST TO TRAN-ID.
    EXEC CICS STARTBR DATASET('TRANSACT') RIDFLD(TRAN-ID)
         KEYLENGTH(16) GTEQ RESP(WS-RESP-CD) END-EXEC.

    EXEC CICS READPREV DATASET('TRANSACT') INTO(TRAN-RECORD)
         RIDFLD(TRAN-ID) RESP(WS-RESP-CD) END-EXEC.

    IF WS-RESP-CD = DFHRESP(NORMAL)
        PERFORM VARYING WS-IDX FROM 1 BY 1
            UNTIL WS-IDX > 10 OR WS-RESP-CD NOT = DFHRESP(NORMAL)
            DISPLAY TRAN-ID TRAN-DESC TRAN-AMT
            EXEC CICS READPREV DATASET('TRANSACT') INTO(TRAN-RECORD)
                 RIDFLD(TRAN-ID) RESP(WS-RESP-CD) END-EXEC
        END-PERFORM
    END-IF.

    IF WS-RESP-CD = DFHRESP(ENDFILE)
        MOVE 'N' TO WS-PREV-PAGE-FLG
    END-IF.
```

### Java Equivalent

```java
// TransactionListService.java
// Source: [program.cbl], PROCESS-PAGE-FORWARD/PROCESS-PAGE-BACKWARD

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class TransactionListService {

    private final TransactionRepository transactionRepository;

    private static final int PAGE_SIZE = 10;

    // Source: PROCESS-PAGE-FORWARD, lines [N]-[M]
    // CICS: STARTBR (GTEQ from lastId) → READNEXT × 10 → ENDBR
    public CursorPageResponse<TransactionDto> pageForward(String lastCursorId, int pageNum) {
        // Read one extra to determine if there's a next page
        List<Transaction> items = transactionRepository.findAfter(lastCursorId,
            PageRequest.ofSize(PAGE_SIZE + 1));

        boolean hasNext = items.size() > PAGE_SIZE;
        if (hasNext) {
            items = items.subList(0, PAGE_SIZE);
        }

        String nextCursor = hasNext
            ? items.get(items.size() - 1).getTransactionId()
            : null;

        // For backward navigation, store firstId for this page
        String prevCursor = (pageNum > 1) ? lastCursorId : null;

        return CursorPageResponse.<TransactionDto>builder()
            .items(items.stream().map(this::mapToDto).toList())
            .pageNum(pageNum + 1)
            .hasNextPage(hasNext)
            .hasPrevPage(pageNum > 1)
            .nextCursor(nextCursor)
            .prevCursor(prevCursor)
            .build();
    }

    // Source: PROCESS-PAGE-BACKWARD, lines [N]-[M]
    // CICS: STARTBR (GTEQ from firstId) → READPREV × 10 → ENDBR
    public CursorPageResponse<TransactionDto> pageBackward(String firstCursorId, int pageNum) {
        // READPREV reads in reverse order; need to reverse the list for display
        List<Transaction> items = transactionRepository.findBefore(firstCursorId,
            PageRequest.ofSize(PAGE_SIZE + 1));

        boolean hasPrev = items.size() > PAGE_SIZE;
        if (hasPrev) {
            items = items.subList(0, PAGE_SIZE);
        }
        Collections.reverse(items); // Reverse to forward order

        String prevCursor = hasPrev
            ? items.get(0).getTransactionId()
            : null;

        return CursorPageResponse.<TransactionDto>builder()
            .items(items.stream().map(this::mapToDto).toList())
            .pageNum(Math.max(1, pageNum - 1))
            .hasNextPage(pageNum > 0)
            .hasPrevPage(hasPrev)
            .nextCursor(firstCursorId)
            .prevCursor(prevCursor)
            .build();
    }

    private TransactionDto mapToDto(Transaction t) {
        return TransactionDto.builder()
            .id(t.getTransactionId())
            .description(t.getDescription())
            .formattedAmount(formatAmount(t.getAmount()))
            .build();
    }

    private String formatAmount(BigDecimal amount) {
        // Source: WS-TRAN-AMT formatting (PIC +99999999.99)
        return String.format("$%,.2f", amount);
    }
}

// TransactionRepository.java — cursor-based pagination methods
@Repository
public interface TransactionRepository extends JpaRepository<Transaction, String> {

    // Source: STARTBR + READNEXT (forward browse)
    @Query("SELECT t FROM Transaction t WHERE t.transactionId > :lastId ORDER BY t.transactionId ASC")
    List<Transaction> findAfter(@Param("lastId") String lastId, Pageable pageable);

    // Source: STARTBR + READPREV (backward browse)
    @Query("SELECT t FROM Transaction t WHERE t.transactionId < :firstId ORDER BY t.transactionId DESC")
    List<Transaction> findBefore(@Param("firstId") String firstId, Pageable pageable);
}

// CursorPageResponse.java — reusable pagination wrapper
@Data @Builder @NoArgsConstructor @AllArgsConstructor
public class CursorPageResponse<T> {
    private List<T> items;
    private Integer pageNum;
    private Boolean hasNextPage;
    private Boolean hasPrevPage;
    private String nextCursor;    // lastId for PF8 (forward)
    private String prevCursor;    // firstId for PF7 (backward)
}
```

---

## Example 4: Batch Program (CBTRN01C) → Spring Batch Job

### COBOL Pattern
```cobol
PROCEDURE DIVISION.
PERFORM OPEN-FILES.

READ DAILY-TRAN
    AT END MOVE 'Y' TO WS-EOF-FLG
END-READ.

PERFORM UNTIL WS-EOF-FLG = 'Y'
    EVALUATE DALYTRAN-FILE-STATUS
        WHEN '00'
            PERFORM LOOKUP-CARD-XREF
            IF WS-XREF-FOUND = 'Y'
                PERFORM LOOKUP-CUST-FILE
                PERFORM LOOKUP-CARD-FILE
                PERFORM LOOKUP-ACCT-FILE
                IF WS-ALL-FOUND = 'Y'
                    PERFORM WRITE-TRANSACT-FILE
                ELSE
                    PERFORM WRITE-REJECT-FILE
                END-IF
            ELSE
                PERFORM WRITE-REJECT-FILE
            END-IF
        WHEN '10'
            MOVE 'Y' TO WS-EOF-FLG
        WHEN OTHER
            MOVE 'Y' TO WS-ERR-FLG
    END-EVALUATE
    READ DAILY-TRAN
        AT END MOVE 'Y' TO WS-EOF-FLG
    END-READ
END-PERFORM.

PERFORM CLOSE-FILES.
```

### Java Equivalent

```java
// DailyTransactionBatchConfig.java
// Source: CBTRN01C.cbl + POSTTRAN.jcl

@Configuration
@RequiredArgsConstructor
public class DailyTransactionBatchConfig {

    private final JobBuilderFactory jobBuilderFactory;
    private final StepBuilderFactory stepBuilderFactory;
    private final CardXrefRepository cardXrefRepository;
    private final CustomerRepository customerRepository;
    private final CardRepository cardRepository;
    private final AccountRepository accountRepository;

    @Bean
    public Job postDailyTransactionsJob() {
        // Source: JCL step sequence: OPENFIL → PROCESS → CLOSEFIL
        return jobBuilderFactory.get("postDailyTransactionsJob")
            .start(openFilesStep())
            .next(postTransactionsStep())
            .next(closeFilesStep())
            .build();
    }

    @Bean
    public Step openFilesStep() {
        return stepBuilderFactory.get("openFilesStep")
            .tasklet((contribution, chunkContext) -> {
                log.info("Opening input file: {}",
                    chunkContext.getStepContext().getJobParameters().get("inputFile"));
                return RepeatStatus.FINISHED;
            })
            .build();
    }

    @Bean
    public Step postTransactionsStep(DataSource dataSource) {
        return stepBuilderFactory.get("postTransactionsStep")
            .<DailyTransactionRecord, Transaction>chunk(100, dataSource)
            .reader(dailyTransactionReader())
            .processor(dailyTransactionProcessor())
            .writer(transactionWriter(dataSource))
            .faultTolerant()
            .skipPolicy(dailyTransactionSkipPolicy())
            .skipLimit(1000)
            .listener(new SkipListenerSupport() {
                @Override
                public void onSkipInProcess(DailyTransactionRecord item, Throwable t) {
                    log.warn("Skipped transaction record: card={}, reason={}",
                        item.getCardNumber(), t.getMessage());
                }
            })
            .build();
    }

    @Bean
    public FlatFileItemReader<DailyTransactionRecord> dailyTransactionReader() {
        // Source: DALYTRAN.PS — RECLN=350, fixed-width format
        return new FlatFileItemReaderBuilder<DailyTransactionRecord>()
            .name("dailyTransactionReader")
            .resource(new FileSystemResource("${batch.input.file:dalytran.dat}"))
            .fixedLength()
            .columns(new Range[]{
                new Range(1, 16),    // DALYTRAN-ID PIC X(16)
                new Range(17, 18),   // DALYTRAN-TYPE-CD PIC X(02)
                new Range(19, 22),   // DALYTRAN-CAT-CD PIC 9(04)
                new Range(23, 32),   // DALYTRAN-SOURCE PIC X(10)
                new Range(33, 132),  // DALYTRAN-DESC PIC X(100)
                new Range(133, 143), // DALYTRAN-AMT PIC S9(09)V99
                new Range(144, 152), // DALYTRAN-MERCHANT-ID PIC 9(09)
                new Range(153, 202), // DALYTRAN-MERCHANT-NAME PIC X(50)
                new Range(203, 252), // DALYTRAN-MERCHANT-CITY PIC X(50)
                new Range(253, 262), // DALYTRAN-MERCHANT-ZIP PIC X(10)
                new Range(263, 278), // DALYTRAN-CARD-NUM PIC X(16)
                new Range(279, 304), // DALYTRAN-ORIG-TS PIC X(26)
                new Range(305, 330)  // DALYTRAN-PROC-TS PIC X(26)
            })
            .names(new String[]{
                "transactionId", "typeCode", "categoryCode", "source",
                "description", "amount", "merchantId", "merchantName",
                "merchantCity", "merchantZip", "cardNumber",
                "originalTimestamp", "processedTimestamp"
            })
            .fieldSetMapper(new BeanWrapperFieldSetMapper<DailyTransactionRecord>() {{
                setTargetType(DailyTransactionRecord.class);
            }})
            .build();
    }

    @Bean
    public ItemProcessor<DailyTransactionRecord, Transaction> dailyTransactionProcessor() {
        // Source: CBTRN01C processing logic:
        // LOOKUP-CARD-XREF → LOOKUP-CUST-FILE → LOOKUP-CARD-FILE → LOOKUP-ACCT-FILE → WRITE-TRANSACT-FILE
        return record -> {
            // LOOKUP-CARD-XREF by card number
            CardXref xref = cardXrefRepository.findById(record.getCardNumber())
                .orElseThrow(() -> new SkipRecordException("Card not found in xref: " + record.getCardNumber()));

            // LOOKUP-CUST-FILE
            Customer customer = customerRepository.findById(xref.getCustomerId())
                .orElseThrow(() -> new SkipRecordException("Customer not found: " + xref.getCustomerId()));

            // LOOKUP-CARD-FILE
            Card card = cardRepository.findById(xref.getCardNumber())
                .orElseThrow(() -> new SkipRecordException("Card not found: " + xref.getCardNumber()));

            // LOOKUP-ACCT-FILE
            Account account = accountRepository.findById(xref.getAccountId())
                .orElseThrow(() -> new SkipRecordException("Account not found: " + xref.getAccountId()));

            // All lookups succeeded — build Transaction entity
            return Transaction.builder()
                .transactionId(record.getTransactionId())
                .typeCode(record.getTypeCode())
                .categoryCode(record.getCategoryCode())
                .source(record.getSource())
                .description(record.getDescription())
                .amount(record.getAmount())
                .merchantId(record.getMerchantId())
                .merchantName(record.getMerchantName())
                .merchantCity(record.getMerchantCity())
                .merchantZip(record.getMerchantZip())
                .cardNumber(record.getCardNumber())
                .originalTimestamp(record.getOriginalTimestamp())
                .processedTimestamp(LocalDateTime.now().format(
                    DateTimeFormatter.ofPattern("yyyy-MM-dd-HH.mm.ss.SSSSSS")))
                .build();
        };
    }

    @Bean
    public JdbcBatchItemWriter<Transaction> transactionWriter(DataSource dataSource) {
        // Source: WRITE-TRANSACT-FILE (VSAM KSDS WRITE)
        return new JdbcBatchItemWriterBuilder<Transaction>()
            .dataSource(dataSource)
            .sql("INSERT INTO transaction (transaction_id, type_code, category_code, " +
                 "source, description, amount, merchant_id, merchant_name, " +
                 "merchant_city, merchant_zip, card_number, original_timestamp, " +
                 "processed_timestamp) " +
                 "VALUES (:transactionId, :typeCode, :categoryCode, " +
                 ":source, :description, :amount, :merchantId, :merchantName, " +
                 ":merchantCity, :merchantZip, :cardNumber, :originalTimestamp, " +
                 ":processedTimestamp)")
            .beanMapped()
            .build();
    }

    @Bean
    public SkipPolicy dailyTransactionSkipPolicy() {
        // Source: EVALUATE DALYTRAN-FILE-STATUS — skip invalid records
        return (throwable, skipCount) -> {
            if (throwable instanceof SkipRecordException) {
                return true; // Skip and log
            }
            if (throwable instanceof FlatFileParseException && skipCount <= 1000) {
                return true; // Skip parse errors
            }
            return false; // All other exceptions fail the job
        };
    }

    @Bean
    public Step closeFilesStep() {
        return stepBuilderFactory.get("closeFilesStep")
            .tasklet((contribution, chunkContext) -> {
                log.info("Batch processing complete. Closing files.");
                return RepeatStatus.FINISHED;
            })
            .build();
    }
}

// SkipRecordException.java
public class SkipRecordException extends RuntimeException {
    public SkipRecordException(String message) {
        super(message);
    }
}
```

---

## Code Review Checklist

Before accepting any generated Java code:
- [ ] All COBOL fields mapped to Java properties (with source refs)
- [ ] All COBOL validations have Bean Validation equivalents
- [ ] All COBOL computations use BigDecimal (never double/float)
- [ ] All COBOL SYNCPOINT → @Transactional
- [ ] All COBOL INVALID KEY → Optional.orElseThrow()
- [ ] All COBOL EVALUATE → switch/enum lookup
- [ ] All COBOL PERFORM → method calls
- [ ] All COBOL file I/O → Repository methods
- [ ] All COBOL paragraph names referenced in Java comments
- [ ] All ID generation uses SEQUENCE/Snowflake (NOT MAX+1)
- [ ] All constructor injection used (NO field injection)
- [ ] All @RequestBody parameters have @Valid
- [ ] All pagination uses cursor-based pattern (findAfter/findBefore, NOT Pageable offset)
- [ ] All batch programs use Spring Batch (NOT plain loops)
- [ ] All BMS maps have Request + Response DTOs
- [ ] All exceptions have HTTP status mapping in GlobalExceptionHandler
- [ ] Test coverage >= 80% for generated code

