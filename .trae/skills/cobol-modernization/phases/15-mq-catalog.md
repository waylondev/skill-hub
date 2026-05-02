# Phase 8f: MQ Message Format Catalog

> **DEPENDS ON:** Phase 5 (Program Logic — MQ operations) + Phase 4 (COPYBOOK — MQ layouts)  
> **OUTPUT:** `08-deliverables/mq-message-catalog.md`

## Objective

Document EVERY MQ message format found in the COBOL source: queue names, message schemas (CSV/JSON/binary), correlation ID patterns, error queues, and trigger configurations. Provide exact field-level schema definitions sufficient for RabbitMQ producer/consumer code generation.

## Why This Phase Is Critical

- MQ message formats in COBOL are typically CSV or fixed-length — they must be precisely documented to avoid message parsing errors
- Correlation ID handling is critical for request-reply patterns (e.g., COPAUA0C authorization)
- Wrong message format → authorization decisions fail silently
- RabbitMQ configuration (exchanges, queues, bindings) derives from this catalog

## CardDemo MQ Inventory

### Queue Inventory

| Queue Name | Type | Direction | Program(s) | Trigger | Purpose |
|-----------|------|-----------|-----------|---------|---------|
| CARD.AUTH.REQUEST.QUEUE | Local → Request | INBOUND (MQGET) | COPAUA0C | CICS MQ Trigger CP00 | Card authorization request from external system |
| CARD.AUTH.REPLY.QUEUE | Local → Reply | OUTBOUND (MQPUT1) | COPAUA0C | — | Authorization response back to requester |
| CARD.ACCT.MQ.REQUEST | Local | INBOUND | COACCT01 | — | Account-related MQ messages |
| CARD.AUTH.TRIGGER | Initiation | SYSTEM | COPAUA0C | MQTM | CICS trigger initiation queue |

### Trigger Configuration

| Trigger Parameter | Value | Source |
|------------------|-------|--------|
| Queue Manager | CSQ1 | COPAUA0C MQOPEN |
| Trigger Monitor | CKTI (CICS) | CICS-transaction CP00 |
| Trigger Type | FIRST | MQTM GET |
| Trigger Interval | 5000ms wait | COPAUA0C GMO-WAIT |
| Max Messages / Trigger | 500 | COPAUA0C WS-LOOP-END |
| CICS Transaction | CP00 | CICS RCT entry |

## Message Format Specifications

### Format 1: CARD.AUTH.REQUEST.QUEUE (CSV)

```
Source: COPAUA0C.cbl, UNSTRING paragraph (lines 700-820)
Format: Comma-separated values, 18 fields
Encoding: EBCDIC (cp037) → must convert to UTF-8 at MQ bridge
```

**Field Schema:**

| Position | Field Name | COBOL PIC | Length | Description | Example |
|----------|-----------|--------|--------|-------------|---------|
| 1 | AUTH-DATE | X(6) | 6 | YYMMDD | 250501 |
| 2 | AUTH-TIME | X(6) | 6 | HHMMSS | 143022 |
| 3 | CARD-NUM | X(16) | 16 | 16-digit card PAN | 4111111111111111 |
| 4 | AUTH-TYPE | X(2) | 2 | Auth type code | 01 |
| 5 | CARD-EXPIRY | X(4) | 4 | YYMM | 2512 |
| 6 | MSG-TYPE | X(4) | 4 | ISO 8583-1 MTI | 0100 |
| 7 | MSG-SOURCE | X(8) | 8 | Source identifier | ACQ00001 |
| 8 | PROCESSING-CODE | X(6) | 6 | Processing code | 000000 |
| 9 | TRANSACTION-AMT | S9(10)V99 | 12 | Amount (no decimal) | 000000015000 (150.00) |
| 10 | MERCHANT-CATEGORY | X(4) | 4 | MCC code | 5812 |
| 11 | ACQ-COUNTRY | X(3) | 3 | ISO country code | 840 |
| 12 | POS-ENTRY-MODE | X(4) | 4 | POS entry mode | 0510 |
| 13 | MERCHANT-ID | X(15) | 15 | Merchant ID | MERCH012345678 |
| 14 | MERCHANT-NAME | X(30) | 30 | Full merchant name | Starbucks #1234 |
| 15 | MERCHANT-CITY | X(20) | 20 | City | Seattle |
| 16 | MERCHANT-STATE | X(2) | 2 | State code | WA |
| 17 | MERCHANT-ZIP | X(10) | 10 | ZIP/Postal | 98101 |
| 18 | TRANSACTION-ID | X(16) | 16 | Unique transaction ref | TXN20250501001 |

**Raw Message Example (EBCDIC CSV with no surrounding quotes):**

```
250501,143022,4111111111111111,01,2512,0100,ACQ00001,000000,000000015000,5812,840,0510,MERCH012345678,Starbucks #1234,Seattle,WA,98101,TXN20250501001
```

**Java POJO:**

```java
// Source: COPAUA0C.cbl, UNSTRING 18 fields → CCPAURQY.cpy
@Data @Builder @NoArgsConstructor @AllArgsConstructor
public class AuthorizationRequest {
    @Pattern(regexp = "^\\d{6}$")
    private String authDate;           // YYMMDD

    @Pattern(regexp = "^\\d{6}$")
    private String authTime;           // HHMMSS

    @Pattern(regexp = "^\\d{16}$")
    private String cardNum;

    @Size(max = 2)
    private String authType;

    @Pattern(regexp = "^\\d{4}$")
    private String cardExpiry;         // YYMM

    @Size(max = 4)
    private String msgType;            // MTI

    @Size(max = 8)
    private String msgSource;

    @Size(max = 6)
    private String processingCode;

    @NotNull @DecimalMin("0.01")
    private BigDecimal transactionAmt; // from PIC S9(10)V99, unpacked

    @Size(max = 4)
    private String merchantCategory;   // MCC

    @Size(max = 3)
    private String acquirerCountry;

    @Size(max = 4)
    private String posEntryMode;

    @Size(max = 15)
    private String merchantId;

    @Size(max = 30)
    private String merchantName;

    @Size(max = 20)
    private String merchantCity;

    @Size(max = 2)
    private String merchantState;

    @Size(max = 10)
    private String merchantZip;

    @Size(max = 16)
    private String transactionId;
}
```

### Format 2: CARD.AUTH.REPLY.QUEUE (STRING Format)

```
Source: COPAUA0C.cbl, STRING paragraph (lines 900-950)
Format: STRING concatenation, 6 fields with fixed positions
Direction: OUTBOUND (MQPUT1 — reply to requester)
```

**Field Schema:**

| Position | Field Name | COBOL PIC | Length | Description |
|----------|-----------|--------|--------|-------------|
| 1 | AUTH-ID-CODE | X(6) | 6 | Authorization response ID |
| 2 | CARD-NUM | X(16) | 16 | Echoed card number |
| 3 | TRANSACTION-ID | X(16) | 16 | Echoed transaction ID |
| 4 | AUTH-RESP-CODE | X(2) | 2 | 00=approved, 05=declined |
| 5 | AUTH-RESP-REASON | X(4) | 4 | Decline reason (3100, 4100, etc.) |
| 6 | APPROVED-AMT | S9(10)V99 | 12 | Approved amount (or 0 if declined) |

**Total message length:** 56 bytes

**Java Producer:**
```java
rabbitTemplate.convertAndSend("auth.reply.exchange", "auth.reply",
    authResponse,
    message -> {
        message.getMessageProperties().setCorrelationId(correlationId);
        return message;
    });
```

### Format 3: CARD.ACCT.MQ.REQUEST (TBD)

```
Source: COACCT01.cbl
Format: To be determined from source analysis
Purpose: Account-related MQ message processing
```

## RabbitMQ Topology Mapping

| COBOL MQ | RabbitMQ | Type |
|----------|---------|------|
| CARD.AUTH.REQUEST.QUEUE | `auth.request.queue` (durable) | Queue |
| CARD.AUTH.REPLY.QUEUE | `auth.reply.queue` (auto-delete) | Queue |
| — | `auth.exchange` | Direct Exchange |
| CARD.AUTH.REQUEST → COPAUA0C | Binding: `auth.exchange` → `auth.request.queue` (rk=`auth.request`) | Binding |
| CARD.AUTH.REPLY → requester | Binding: `auth.exchange` → `auth.reply.queue` (rk=`auth.reply`) | Binding |
| MQTM TRIGGER | Spring `@RabbitListener` on `auth.request.queue` | Consumer |
| MQPUT1 REPLY | `RabbitTemplate.convertAndSend()` | Producer |

## Correlation ID Pattern

```
Source: COPAUA0C.cbl, lines GMO-MSGID-OPTION
COBOL: MQGET with GMO-MATCH-CORREL-ID
       MQPUT1 with PMO-DEFAULT-CONTEXT (preserves MsgId → CorrelId)

Java:
  Consumer: message.getMessageProperties().getCorrelationId()
  Producer: message.getMessageProperties().setCorrelationId(request.getCorrelationId())
```

## Error Handling

| COBOL MQ Error | Condition | Spring Equivalent |
|---------------|----------|-------------------|
| MQRC_NO_MSG_AVAILABLE (2033) | GET timeout (5s) | `@RabbitListener` timeout → `null` check |
| MQRC_Q_MGR_NOT_AVAILABLE (2059) | Queue Manager down | `AmqpConnectException` → `RabbitMQHealthIndicator` |
| MQRC_CONNECTION_BROKEN (2009) | TCP disconnect | `CachingConnectionFactory` auto-reconnect |
| MQPUT1 failure | Reply queue full | `AmqpException` → log + dead-letter |

## Execution Steps

### Step 1: Grep for MQ Commands

Search ALL COBOL source for: `MQOPEN`, `MQGET`, `MQPUT`, `MQPUT1`, `MQCLOSE`, `MQIEP`, `MQTM`

### Step 2: Extract Queue Names

From MQOD-OBJECT-NAME assignments.

### Step 3: Parse Message Formats

From UNSTRING/STRING MOVE statements.

### Step 4: Generate Java POJOs

Create exact DTO classes for each message format.

### Step 5: Generate RabbitMQ Config

Create exchanges, queues, bindings, DeadLetterConfig.

### Step 6: Export

Write `08-deliverables/mq-message-catalog.md`.

## Quality Gate

- [ ] All MQ queue names documented with inbound/outbound direction
- [ ] All MQ message formats have complete field schemas
- [ ] Correlation ID propagation documented for request-reply
- [ ] RabbitMQ topology diagram generated
- [ ] Java DTOs for ALL message formats
- [ ] Error handling strategy defined for ALL MQ error codes
- [ ] EBCDIC → UTF-8 conversion plan for mainframe-originated messages
