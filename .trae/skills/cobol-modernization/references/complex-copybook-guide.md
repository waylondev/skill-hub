# Complex COPYBOOK Handling Guide

## Overview

This guide covers advanced COPYBOOK patterns that require special handling during COBOL→Java migration: REDEFINES, OCCURS (including OCCURS DEPENDING ON), nested OCCURS, 77-level redefines, and COPY REPLACING with dynamic field name changes.

## REDEFINES Patterns

### Type 1: Type Discriminator REDEFINES

The most common pattern — a discriminator field determines which view of the data is active.

**COBOL Source:**
```cobol
01  TRANSACTION-RECORD.
    05  TRAN-TYPE          PIC X(02).
        88 TRAN-DEPOSIT    VALUE '01'.
        88 TRAN-WITHDRAWAL VALUE '02'.
        88 TRAN-TRANSFER   VALUE '03'.
    05  TRAN-DATA.
        10  DEPOSIT-AMOUNT     PIC S9(07)V99.
        10  DEPOSIT-ACCOUNT    PIC X(12).
    05  TRAN-DATA-ALT REDEFINES TRAN-DATA.
        10  WITHDRAW-AMOUNT    PIC S9(07)V99.
        10  WITHDRAW-ACCOUNT   PIC X(12).
        10  WITHDRAW-CHECK-NBR PIC X(08).
    05  TRAN-DATA-TRF REDEFINES TRAN-DATA.
        10  FROM-ACCOUNT       PIC X(12).
        10  TO-ACCOUNT         PIC X(12).
        10  TRANSFER-AMOUNT    PIC S9(07)V99.
```

**Java Strategy: @Inheritance (SINGLE_TABLE)**
```java
// Source: TRANSACTION-RECOPY, lines 1-18
@Inheritance(strategy = InheritanceType.SINGLE_TABLE)
@DiscriminatorColumn(name = "tran_type", discriminatorType = DiscriminatorType.STRING, length = 2)
@Entity
@Table(name = "transaction")
public abstract class Transaction {
    @Id
    @GeneratedValue(strategy = GenerationType.SEQUENCE, generator = "tran_seq")
    private Long id;
    
    public abstract TransactionType getTranType();
}

@Entity
@DiscriminatorValue("01")
public class DepositTransaction extends Transaction {
    @Override
    public TransactionType getTranType() { return TransactionType.DEPOSIT; }
    
    @Column(name = "amount", nullable = false, precision = 9, scale = 2)
    private BigDecimal depositAmount;
    
    @Column(name = "deposit_account", length = 12)
    private String depositAccount;
}

@Entity
@DiscriminatorValue("02")
public class WithdrawalTransaction extends Transaction {
    @Override
    public TransactionType getTranType() { return TransactionType.WITHDRAWAL; }
    
    @Column(name = "amount", nullable = false, precision = 9, scale = 2)
    private BigDecimal withdrawAmount;
    
    @Column(name = "withdraw_account", length = 12)
    private String withdrawAccount;
    
    @Column(name = "check_number", length = 8)
    private String withdrawCheckNbr;
}

@Entity
@DiscriminatorValue("03")
public class TransferTransaction extends Transaction {
    @Override
    public TransactionType getTranType() { return TransactionType.TRANSFER; }
    
    @Column(name = "from_account", length = 12)
    private String fromAccount;
    
    @Column(name = "to_account", length = 12)
    private String toAccount;
    
    @Column(name = "amount", nullable = false, precision = 9, scale = 2)
    private BigDecimal transferAmount;
}

// Enum for discriminator
@Getter
public enum TransactionType {
    DEPOSIT("01"),
    WITHDRAWAL("02"),
    TRANSFER("03");
    
    private final String code;
    TransactionType(String code) { this.code = code; }
    
    public static TransactionType fromCode(String code) {
        for (TransactionType v : values()) {
            if (v.code.equals(code)) return v;
        }
        throw new IllegalArgumentException("Unknown TransactionType: " + code);
    }
}
```

### Type 2: Alternate View REDEFINES

Same data viewed through different lenses (no discriminator).

**COBOL Source:**
```cobol
01  ACCOUNT-NUMBER.
    05  ACCT-NUMBER-FULL     PIC X(12).
01  ACCOUNT-NUMBER-PARSED REDEFINES ACCOUNT-NUMBER.
    05  ACCT-BANK-CODE       PIC X(04).
    05  ACCT-BRANCH-CODE     PIC X(04).
    05  ACCT-SEQUENCE        PIC X(04).
```

**Java Strategy: @Embeddable**
```java
// Source: ACCOUNT-RECOPY, lines 1-7
@Embeddable
public class AccountNumber implements Serializable {
    
    @Column(name = "account_full", length = 12)
    private String fullNumber;
    
    @Column(name = "bank_code", length = 4)
    private String bankCode;
    
    @Column(name = "branch_code", length = 4)
    private String branchCode;
    
    @Column(name = "sequence", length = 4)
    private String sequence;
    
    public AccountNumber() {}
    
    public AccountNumber(String full) {
        this.fullNumber = full;
        this.bankCode = full.substring(0, 4);
        this.branchCode = full.substring(4, 8);
        this.sequence = full.substring(8, 12);
    }
    
    // Getters, setters, equals, hashCode
}
```

### Type 3: Variable-Length REDEFINES

Different data structures sharing same memory based on context.

**COBOL Source:**
```cobol
01  MESSAGE-RECORD.
    05  MSG-HEADER.
        10  MSG-LENGTH       PIC 9(04).
        10  MSG-TYPE         PIC X(02).
    05  MSG-BODY.
        10  MSG-SHORT        PIC X(50)   WHEN MSG-LENGTH <= 50.
    05  MSG-BODY-LONG REDEFINES MSG-BODY.
        10  MSG-TEXT         PIC X(200)  WHEN MSG-LENGTH > 50.
    05  MSG-BINARY REDEFINES MSG-BODY.
        10  MSG-DATA         PIC X(250).
```

**Java Strategy: Sealed Classes (Java 17+)**
```java
// Source: MESSAGE-RECOPY, lines 1-11
public sealed interface MessageBody {
    ShortMessage asShort();
    LongMessage asLong();
    BinaryMessage asBinary();
}

public record ShortMessage(String text) implements MessageBody {
    public ShortMessage { Objects.requireNonNull(text); }
    @Override public ShortMessage asShort() { return this; }
    @Override public LongMessage asLong() { return null; }
    @Override public BinaryMessage asBinary() { return null; }
}

public record LongMessage(String text) implements MessageBody {
    @Override public ShortMessage asShort() { return null; }
    @Override public LongMessage asLong() { return this; }
    @Override public BinaryMessage asBinary() { return null; }
}

public record BinaryMessage(byte[] data) implements MessageBody {
    @Override public ShortMessage asShort() { return null; }
    @Override public LongMessage asLong() { return null; }
    @Override public BinaryMessage asBinary() { return this; }
}
```

## OCCURS Patterns

### Fixed OCCURS

**COBOL:**
```cobol
05  ORDER-DETAILS OCCURS 5 TIMES.
    10  ORDER-ITEM-NBR   PIC 9(04).
    10  ORDER-ITEM-QTY   PIC 9(03).
    10  ORDER-ITEM-PRICE PIC S9(05)V99.
```

**Java:**
```java
// Source: ORDER-RECOPY, lines 1-5
@ElementCollection
@CollectionTable(name = "order_details", joinColumns = @JoinColumn(name = "order_id"))
private List<OrderDetail> orderDetails = new ArrayList<>(5);

@Embeddable
public class OrderDetail {
    @Column(name = "item_nbr", nullable = false)
    private Integer itemNbr;
    
    @Column(name = "quantity", nullable = false)
    private Integer quantity;
    
    @Column(name = "price", nullable = false, precision = 7, scale = 2)
    private BigDecimal price;
}
```

### OCCURS DEPENDING ON (Variable Length Array)

**COBOL:**
```cobol
01  GROUP-RECORD.
    05  MEMBER-COUNT         PIC 9(03).
    05  MEMBER-DATA          OCCURS 1 TO 100 TIMES
                             DEPENDING ON MEMBER-COUNT.
        10  MEMBER-ID        PIC X(10).
        10  MEMBER-NAME      PIC X(30).
        10  MEMBER-ROLE      PIC X(01).
```

**Java:**
```java
// Source: GROUP-RECOPY, lines 1-8
@Entity
@Table(name = "groups")
public class Group {
    
    @Column(name = "member_count")
    private Integer memberCount;
    
    @OneToMany(mappedBy = "group", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<Member> members = new ArrayList<>();
    
    // Validation
    @PostLoad
    void validateMemberCount() {
        if (memberCount != members.size()) {
            throw new DataIntegrityViolationException(
                "Member count mismatch: expected=" + memberCount + ", actual=" + members.size());
        }
    }
    
    public void addMember(Member m) {
        members.add(m);
        m.setGroup(this);
        memberCount = members.size();
    }
}

@Entity
@Table(name = "members")
public class Member {
    @ManyToOne
    @JoinColumn(name = "group_id")
    private Group group;
    
    @Column(name = "member_id", length = 10, nullable = false)
    private String memberId;
    
    @Column(name = "member_name", length = 30)
    private String memberName;
    
    @Enumerated(EnumType.STRING)
    @Column(name = "role", length = 1)
    private MemberRole role;
}
```

### Nested OCCURS

**COBOL:**
```cobol
01  INVOICE-RECORD.
    05  INVOICE-NO           PIC X(10).
    05  INVOICE-LINES OCCURS 10 TIMES.
        10  LINE-NBR         PIC 9(03).
        10  LINE-AMOUNT      PIC S9(07)V99.
        10  LINE-ITEMS OCCURS 5 TIMES.
            15  ITEM-SKU     PIC X(15).
            15  ITEM-QTY     PIC 9(05).
```

**Java:**
```java
// Source: INVOICE-RECOPY, lines 1-9
@Entity
@Table(name = "invoices")
public class Invoice {
    @Id
    @Column(name = "invoice_no", length = 10)
    private String invoiceNo;
    
    @OneToMany(mappedBy = "invoice", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<InvoiceLine> lines = new ArrayList<>(10);
}

@Entity
@Table(name = "invoice_lines")
public class InvoiceLine {
    @Id
    @GeneratedValue(strategy = GenerationType.SEQUENCE)
    private Long id;
    
    @ManyToOne
    @JoinColumn(name = "invoice_no")
    private Invoice invoice;
    
    @Column(name = "line_nbr")
    private Integer lineNbr;
    
    @Column(name = "amount", precision = 9, scale = 2)
    private BigDecimal amount;
    
    @OneToMany(mappedBy = "line", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<LineItem> items = new ArrayList<>(5);
}

@Entity
@Table(name = "line_items")
public class LineItem {
    @Id
    @GeneratedValue(strategy = GenerationType.SEQUENCE)
    private Long id;
    
    @ManyToOne
    @JoinColumn(name = "line_id")
    private InvoiceLine line;
    
    @Column(name = "sku", length = 15)
    private String sku;
    
    @Column(name = "quantity")
    private Integer quantity;
}
```

## COPY REPLACING Advanced Patterns

### Pattern 1: Field Name Replacement

```cobol
* In program A:
COPY ACCTREC REPLACING ==ACCT-ID== BY ==CUST-ID==.

* In program B:
COPY ACCTREC REPLACING ==ACCT-ID== BY ==VENDOR-ID==.
```

**Strategy:** The Entity uses the original COPYBOOK name, but document all program-specific field aliases.

```java
// Source: ACCTREC (original), used by:
//   - Program A: ACCT-ID REPLACED BY CUST-ID
//   - Program B: ACCT-ID REPLACED BY VENDOR-ID
@Entity
@Table(name = "accounts")
public class Account {
    // Note: This field is referenced as CUST-ID in Program A
    // and as VENDOR-ID in Program B
    @Column(name = "account_id", length = 12)
    private String accountId;
}
```

### Pattern 2: Prefix Replacement

```cobol
COPY ACCTREC REPLACING LEADING ==WS-== BY ==DB-==.
```

**Strategy:** Document the prefix mapping in the COPY REPLACING Registry.

### Pattern 3: Literal Replacement

```cobol
COPY ACCTREC REPLACING ==PIC X(10)== BY ==PIC X(20)==.
```

**Strategy:** Use the maximum length across all programs.

```java
@Column(name = "field_name", length = 20)  // Max of X(10) and X(20)
private String fieldName;
```

## Decision Matrix

| COPYBOOK Pattern | Java Strategy | When to Use |
|-----------------|---------------|-------------|
| Simple REDEFINES with discriminator | `@Inheritance(SINGLE_TABLE)` | Clear type discriminator field |
| REDEFINES without discriminator | `@Embeddable` with computed fields | Same data, different views |
| REDEFINES with length variation | Sealed interfaces (Java 17+) | Type varies by length/context |
| Fixed OCCURS | `@ElementCollection` or `List<T>` | Array size known at compile time |
| OCCURS DEPENDING ON | `@OneToMany(cascade=ALL)` | Variable length array |
| Nested OCCURS | Nested `@OneToMany` relationships | Multi-dimensional arrays |
| COPY REPLACING field name | Single Entity + alias table | Field name varies by program |
| COPY REPLACING length | Maximum length across programs | Size varies by program |

## Handling Checklist

- [ ] Every REDEFINES analyzed and mapped to Java strategy
- [ ] Every OCCURS converted to List<T> with proper JPA annotation
- [ ] Every OCCURS DEPENDING ON has validation for count consistency
- [ ] Every nested OCCURS has proper cascade configuration
- [ ] Every COPY REPLACING documented in registry
- [ ] Maximum lengths used when REPLACING changes PIC sizes
- [ ] Discriminator enums generated from 88-level conditions
- [ ] @Embeddable classes have proper equals/hashCode implementations