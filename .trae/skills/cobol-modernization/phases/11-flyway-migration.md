# Phase 8b: Flyway Database Migration Script Generation

> **DEPENDS ON:** Phase 2 (VSAM) + Phase 4 (COPYBOOK) + Phase 8a (DTO)  
> **OUTPUT:** `09-database-migrations/V1__initial_schema.sql` + `V2__indexes_and_constraints.sql` + `V3__seed_data.sql`

## Objective

Generate complete, executable Flyway migration SQL scripts that transform COBOL VSAM/DB2/IMS data models into a relational PostgreSQL schema. Each script must be ready to run against a PostgreSQL 15+ instance.

## Why This Phase Is Critical

- VSAM files are not relational — the schema redesign is the foundation for all JPA entities
- COMP-3 packed decimals need explicit column type decisions
- DB2 and IMS data models need normalization into a unified relational model
- Index design must replicate VSAM AIX behavior for correct query performance
- Seed data from golden test files enables immediate integration testing

## Flyway Versioning Convention

| Version | File | Purpose |
|---------|------|---------|
| V1__initial_schema.sql | Tables + Primary Keys | Core entity tables |
| V2__indexes_and_constraints.sql | Foreign Keys + Indexes + Unique Constraints | Data integrity + AIX equivalent |
| V3__seed_data.sql | INSERT seed data | Golden test data for integration tests |
| V4__comp3_migration.sql | COMP-3 → BigDecimal | If COMP-3 exists (created on demand) |

## Schema Generation Rules

### Rule 1: COBOL PIC → SQL Type

| COBOL PIC | PostgreSQL Type | Notes |
|-----------|----------------|-------|
| X(N) | `VARCHAR(N)` | N < 256 chars |
| X(N > 255) | `TEXT` | Large text fields |
| 9(N) | `BIGINT` or `VARCHAR(N)` | BIGINT if purely numeric; VARCHAR if leading zeros matter (e.g. account IDs) |
| S9(N)V99 | `NUMERIC(11, 2)` | Precision = N+2, scale = 2 |
| S9(N) COMP | `INTEGER` or `BIGINT` | Binary counter fields |
| S9(N)V99 COMP-3 | `NUMERIC(N+2, 2)` | Packed decimal → explicit precision |
| 88-LEVEL (enum) | `VARCHAR(1)` or `VARCHAR(N)` | Short code storage |
| FILLER | `VARCHAR(N)` (reserved) | Document but include as reserved column |

### Rule 2: VSAM AIX → PostgreSQL Index

| VSAM AIX | PostgreSQL |
|----------|-----------|
| Alternate Index on CARD-DATA by ACCT-ID | `CREATE INDEX idx_cards_acct_id ON cards(acct_id)` |
| Path key on XREF by ACCT-ID | `CREATE INDEX idx_card_xref_acct_id ON card_xref(acct_id)` |

### Rule 3: Composite Key → Composite Primary Key

| VSAM | PostgreSQL |
|------|-----------|
| TRANCATG key=TRAN-TYPE-CD(2)+TRAN-CAT-CD(2) | `PRIMARY KEY (tran_type_cd, tran_cat_cd)` |
| DISCGRP key=ACCT-GROUP-ID(11)+TRAN-TYPE-CD(2)+TRAN-CAT-CD(2) | `PRIMARY KEY (acct_group_id, tran_type_cd, tran_cat_cd)` |
| TCATBALF key=ACCT-ID(11)+TRAN-TYPE-CD(2)+TRAN-CAT-CD(2) | `PRIMARY KEY (acct_id, tran_type_cd, tran_cat_cd)` |

### Rule 4: COBOL Date/Time → SQL

| COBOL Field | Format | PostgreSQL |
|------------|--------|-----------|
| PIC X(10) date (MM/DD/YYYY) | Display | `DATE` |
| PIC X(26) timestamp | CICS ASKTIME | `TIMESTAMP` |
| PIC X(6) time (HHMMSS) | CICS FORMATTIME | `TIME` |
| PIC X(4) date (YYMM) | Card expiry | `VARCHAR(4)` (preserve format) |
| 9(5) descending date | IMS key (99999-DATE) | `INTEGER` |

## V1: Initial Schema

```sql
-- ============================================================
-- V1__initial_schema.sql
-- CardDemo v4 — Database Schema Migration
-- Source: COBOL COPYBOOKs + VSAM Files + DB2 DDL
-- Generated: YYYY-MM-DD
-- Target: PostgreSQL 15+
-- ============================================================

-- Source: CVCUS01Y.cpy, CUSTREC.cpy — CUSTDATA VSAM KSDS
CREATE TABLE customers (
    cust_id         BIGINT          NOT NULL,
    first_name      VARCHAR(20),
    middle_name     VARCHAR(20),
    last_name       VARCHAR(20)     NOT NULL,
    addr_line1      VARCHAR(30),
    addr_line2      VARCHAR(30),
    addr_line3      VARCHAR(30),
    state           VARCHAR(2),
    zip             VARCHAR(10),
    phone1          VARCHAR(12),
    phone2          VARCHAR(12),
    email           VARCHAR(50),
    dob             DATE,
    ssn             VARCHAR(9),
    open_date       DATE,
    reserved        VARCHAR(100),
    created_at      TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,
    version         BIGINT          DEFAULT 0,
    PRIMARY KEY (cust_id)
);

-- Source: CVACT01Y.cpy — ACCTDATA VSAM KSDS
CREATE TABLE accounts (
    acct_id             BIGINT          NOT NULL,
    cust_id             BIGINT          NOT NULL,  -- FK→customers
    acct_status         VARCHAR(1)      NOT NULL DEFAULT 'A',  -- 88: A, I, O
    acct_group_id       BIGINT,
    curr_bal            NUMERIC(11,2)   DEFAULT 0,
    credit_limit        NUMERIC(9,2),
    cash_credit_limit   NUMERIC(7,2),
    open_date           DATE,
    expira_date         DATE,
    reissue_date        DATE,
    last_activity_date  TIMESTAMP,
    billing_cycle       INTEGER,
    interest_rate       NUMERIC(4,2)    DEFAULT 0,
    reserved            VARCHAR(200),
    created_at          TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,
    version             BIGINT          DEFAULT 0,
    PRIMARY KEY (acct_id)
);

-- Source: CVACT02Y.cpy — CARDDATA VSAM KSDS
CREATE TABLE cards (
    card_num        VARCHAR(16)     NOT NULL,
    cust_id         BIGINT          NOT NULL,  -- FK→customers
    acct_id         BIGINT          NOT NULL,  -- FK→accounts
    card_status     VARCHAR(1)      NOT NULL DEFAULT 'A',  -- 88: A, I, L
    exp_date        VARCHAR(4),     -- YYMM format
    cvv             VARCHAR(3),
    issue_date      DATE,
    name_on_card    VARCHAR(30),
    primary_flag    VARCHAR(1)      DEFAULT 'N',  -- Y or N
    reserved        VARCHAR(100),
    created_at      TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,
    version         BIGINT          DEFAULT 0,
    PRIMARY KEY (card_num)
);

-- Source: CVACT03Y.cpy — CARDXREF VSAM KSDS
CREATE TABLE card_xref (
    card_num        VARCHAR(16)     NOT NULL,  -- PK + FK→cards
    cust_id         BIGINT          NOT NULL,  -- FK→customers
    acct_id         BIGINT          NOT NULL,  -- FK→accounts
    card_status     VARCHAR(1),  -- 88: A, I, L
    reserved        VARCHAR(40),
    created_at      TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,
    version         BIGINT          DEFAULT 0,
    PRIMARY KEY (card_num)
);

-- Source: CVTRA01Y.cpy — TRANSACT VSAM KSDS
CREATE TABLE transactions (
    tran_id         VARCHAR(16)     NOT NULL,
    tran_type       VARCHAR(2),     -- FK→tran_types
    tran_cat_cd     VARCHAR(2),     -- FK→tran_categories
    card_num        VARCHAR(16),    -- FK→cards
    acct_id         BIGINT,         -- FK→accounts
    tran_amt        NUMERIC(11,2)   NOT NULL,
    tran_date       DATE,
    tran_time       VARCHAR(6),     -- HHMMSS
    merchant_id     VARCHAR(15),
    merchant_name   VARCHAR(30),
    merchant_city   VARCHAR(20),
    merchant_state  VARCHAR(2),
    merchant_zip    VARCHAR(10),
    tran_status     VARCHAR(1)      DEFAULT 'P',  -- P, O, R
    tran_desc       VARCHAR(50),
    reserved        VARCHAR(50),
    created_at      TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,
    version         BIGINT          DEFAULT 0,
    PRIMARY KEY (tran_id)
);

-- Source: CVTRA03Y.cpy — TRANTYPE VSAM KSDS
CREATE TABLE tran_types (
    tran_type       VARCHAR(2)      NOT NULL,
    tran_type_desc  VARCHAR(30),
    reserved        VARCHAR(60),
    created_at      TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,
    version         BIGINT          DEFAULT 0,
    PRIMARY KEY (tran_type)
);

-- Source: CVTRA02Y.cpy — TRANCATG VSAM KSDS (composite key)
CREATE TABLE tran_categories (
    tran_type_cd    VARCHAR(2)      NOT NULL,
    tran_cat_cd     VARCHAR(2)      NOT NULL,
    tran_cat_desc   VARCHAR(30),
    reserved        VARCHAR(44),
    created_at      TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,
    version         BIGINT          DEFAULT 0,
    PRIMARY KEY (tran_type_cd, tran_cat_cd)
);

-- Source: CVTRA04Y.cpy — DISCGRP VSAM KSDS (composite key)
CREATE TABLE discount_groups (
    acct_group_id   BIGINT          NOT NULL,
    tran_type_cd    VARCHAR(2)      NOT NULL,
    tran_cat_cd     VARCHAR(2)      NOT NULL,
    disc_percent    NUMERIC(4,2),
    reserved        VARCHAR(30),
    created_at      TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,
    version         BIGINT          DEFAULT 0,
    PRIMARY KEY (acct_group_id, tran_type_cd, tran_cat_cd)
);

-- Source: CVTRA05Y.cpy — TCATBALF VSAM KSDS (composite key)
CREATE TABLE tcat_balances (
    acct_id         BIGINT          NOT NULL,  -- FK→accounts
    tran_type_cd    VARCHAR(2)      NOT NULL,
    tran_cat_cd     VARCHAR(2)      NOT NULL,
    acct_tran_amt   NUMERIC(11,2)   DEFAULT 0,
    acct_tran_count INTEGER         DEFAULT 0,
    reserved        VARCHAR(30),
    created_at      TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,
    version         BIGINT          DEFAULT 0,
    PRIMARY KEY (acct_id, tran_type_cd, tran_cat_cd)
);

-- Source: CVTRA07Y.cpy — USRSEC VSAM KSDS
-- ⚠️ SECURITY: COBOL stores plaintext passwords; BCrypt migration required
CREATE TABLE users (
    user_id         VARCHAR(8)      NOT NULL,
    password_hash   VARCHAR(255)    NOT NULL,  -- BCrypt hashed
    user_type       VARCHAR(1)      NOT NULL DEFAULT 'U',  -- A, U
    user_name       VARCHAR(30),
    last_login      TIMESTAMP,
    reserved        VARCHAR(100),
    created_at      TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,
    version         BIGINT          DEFAULT 0,
    PRIMARY KEY (user_id)
);

-- NEW: Sub-App 1 — Authorization (from IMS segments + DB2 tables)
-- Source: CIPAUSMY.cpy — Auth Summary Segment (IMS Root)
CREATE TABLE auth_summary (
    acct_id             BIGINT          NOT NULL,
    cust_id             BIGINT          NOT NULL,
    credit_limit        NUMERIC(11,2)   DEFAULT 0,
    credit_balance      NUMERIC(11,2)   DEFAULT 0,
    cash_limit          NUMERIC(7,2)    DEFAULT 0,
    cash_balance        NUMERIC(7,2)    DEFAULT 0,
    approved_auth_cnt   INTEGER         DEFAULT 0,
    declined_auth_cnt   INTEGER         DEFAULT 0,
    approved_auth_amt   NUMERIC(9,2)    DEFAULT 0,
    declined_auth_amt   NUMERIC(9,2)    DEFAULT 0,
    created_at          TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,
    version             BIGINT          DEFAULT 0,
    PRIMARY KEY (acct_id)
);

-- Source: CIPAUDTY.cpy — Auth Detail Segment (IMS Child)
CREATE TABLE auth_detail (
    auth_id             BIGSERIAL       NOT NULL,
    acct_id             BIGINT          NOT NULL,  -- FK→auth_summary
    auth_key            VARCHAR(8),     -- unique IMS key
    auth_date_desc      INTEGER,        -- descending date (99999-date)
    auth_time_desc      BIGINT,         -- descending time
    auth_date           VARCHAR(6),     -- YYMMDD
    auth_time           VARCHAR(6),     -- HHMMSS
    card_num            VARCHAR(16),
    transaction_amt     NUMERIC(12,2),
    auth_resp_code      VARCHAR(2),     -- 00 approved, 05 declined
    auth_resp_reason    VARCHAR(4),     -- decline reason code
    approved_amt        NUMERIC(12,2),
    match_status        VARCHAR(8),
    fraud_flag          VARCHAR(1),
    merchant_id         VARCHAR(15),
    transaction_id      VARCHAR(16),
    created_at          TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,
    version             BIGINT          DEFAULT 0,
    PRIMARY KEY (auth_id)
);

-- NEW: Sub-App 2 — Transaction Types (from DB2 TRANSACTION_TYPE table)
-- Source: DB2 DDL files (app-transaction-type-db2/ddl/)
-- DB2: DECIMAL(6,0) → NUMERIC, VARCHAR(N) → same
CREATE TABLE db2_tran_types (
    tran_type       VARCHAR(2)      NOT NULL,
    description     VARCHAR(50),
    created_at      TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,
    version         BIGINT          DEFAULT 0,
    PRIMARY KEY (tran_type)
);

CREATE TABLE db2_tran_categories (
    tran_type_cd    VARCHAR(2)      NOT NULL,
    tran_cat_cd     VARCHAR(2)      NOT NULL,
    description     VARCHAR(50),
    created_at      TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,
    version         BIGINT          DEFAULT 0,
    PRIMARY KEY (tran_type_cd, tran_cat_cd)
);
```

## V2: Indexes & Constraints

```sql
-- ============================================================
-- V2__indexes_and_constraints.sql
-- Foreign Keys, Indexes (AIX equivalents), Unique Constraints
-- ============================================================

-- Foreign Keys (VSAM implicit relationships → explicit FK)
ALTER TABLE accounts ADD CONSTRAINT fk_accounts_customer
    FOREIGN KEY (cust_id) REFERENCES customers(cust_id);

ALTER TABLE cards ADD CONSTRAINT fk_cards_customer
    FOREIGN KEY (cust_id) REFERENCES customers(cust_id);

ALTER TABLE cards ADD CONSTRAINT fk_cards_account
    FOREIGN KEY (acct_id) REFERENCES accounts(acct_id);

ALTER TABLE card_xref ADD CONSTRAINT fk_card_xref_card
    FOREIGN KEY (card_num) REFERENCES cards(card_num);

ALTER TABLE card_xref ADD CONSTRAINT fk_card_xref_customer
    FOREIGN KEY (cust_id) REFERENCES customers(cust_id);

ALTER TABLE card_xref ADD CONSTRAINT fk_card_xref_account
    FOREIGN KEY (acct_id) REFERENCES accounts(acct_id);

ALTER TABLE transactions ADD CONSTRAINT fk_transactions_card
    FOREIGN KEY (card_num) REFERENCES cards(card_num);

ALTER TABLE transactions ADD CONSTRAINT fk_transactions_account
    FOREIGN KEY (acct_id) REFERENCES accounts(acct_id);

ALTER TABLE transactions ADD CONSTRAINT fk_transactions_tran_type
    FOREIGN KEY (tran_type) REFERENCES tran_types(tran_type);

ALTER TABLE tcat_balances ADD CONSTRAINT fk_tcat_balances_account
    FOREIGN KEY (acct_id) REFERENCES accounts(acct_id);

ALTER TABLE auth_detail ADD CONSTRAINT fk_auth_detail_summary
    FOREIGN KEY (acct_id) REFERENCES auth_summary(acct_id);

-- VSAM AIX → PostgreSQL Indexes
-- Source: CARDAIX (Alternate Index on CARDDATA by ACCT-ID)
CREATE INDEX idx_cards_acct_id ON cards(acct_id);

-- Source: CXACAIX (Alternate Index on CARDXREF by ACCT-ID)
CREATE INDEX idx_card_xref_acct_id ON card_xref(acct_id);

-- Common lookup indexes
CREATE INDEX idx_accounts_cust_id ON accounts(cust_id);
CREATE INDEX idx_accounts_status ON accounts(acct_status);

CREATE INDEX idx_cards_cust_id ON cards(cust_id);
CREATE INDEX idx_cards_status ON cards(card_status);

CREATE INDEX idx_transactions_acct_id ON transactions(acct_id);
CREATE INDEX idx_transactions_card_num ON transactions(card_num);
CREATE INDEX idx_transactions_date ON transactions(tran_date);
CREATE INDEX idx_transactions_status ON transactions(tran_status);
CREATE INDEX idx_transactions_type_acct_date
    ON transactions(tran_type, acct_id, tran_date);

CREATE INDEX idx_tcat_balances_tran_type ON tcat_balances(tran_type_cd, tran_cat_cd);

-- Auth indexes (IMS path traversal → SQL index)
CREATE INDEX idx_auth_detail_acct_date ON auth_detail(acct_id, auth_date_desc);
CREATE INDEX idx_auth_detail_card ON auth_detail(card_num);
CREATE INDEX idx_auth_detail_txn ON auth_detail(transaction_id);

-- DB2 indexes
CREATE INDEX idx_db2_tran_types_desc ON db2_tran_types(description);

-- Unique constraints
ALTER TABLE card_xref ADD CONSTRAINT uk_card_xref_cust_acct
    UNIQUE (cust_id, acct_id, card_num);

-- Check constraints (88-level → DB constraint)
ALTER TABLE accounts ADD CONSTRAINT ck_accounts_status
    CHECK (acct_status IN ('A', 'I', 'O'));

ALTER TABLE cards ADD CONSTRAINT ck_cards_status
    CHECK (card_status IN ('A', 'I', 'L'));

ALTER TABLE users ADD CONSTRAINT ck_users_type
    CHECK (user_type IN ('A', 'U'));

ALTER TABLE transactions ADD CONSTRAINT ck_transactions_status
    CHECK (tran_status IN ('P', 'O', 'R'));
```

## V3: Seed Data

```sql
-- ============================================================
-- V3__seed_data.sql
-- Golden test data from demo data files
-- Source: demo/aws-mainframe-modernization-carddemo/app/data/
-- ⚠️ CAUTION: passwords are PLAINTEXT in COBOL; BCrypt hashes used here
-- ============================================================

-- Admin user (COBOL: SEC-USR-ID='admin01', SEC-USR-TYPE='A')
INSERT INTO users (user_id, password_hash, user_type, user_name)
VALUES ('admin01', '$2a$10$...bcrypt_admin...', 'A', 'Admin User');

-- Regular user (COBOL: SEC-USR-ID='user01', SEC-USR-TYPE='U')
INSERT INTO users (user_id, password_hash, user_type, user_name)
VALUES ('user01', '$2a$10$...bcrypt_user...', 'U', 'Test User');

-- Seed customers (from COBOL test data in ASCII format)
INSERT INTO customers (cust_id, first_name, last_name, addr_line1, email, dob)
VALUES
  (1, 'John',  'Smith',   '123 Main St',     'john@test.com', '1985-01-15'),
  (2, 'Jane',  'Johnson', '456 Oak Ave',     'jane@test.com', '1990-05-20'),
  (3, 'Bob',   'Williams','789 Pine Rd',     'bob@test.com',  '1975-11-08');

-- Seed accounts linked to customers
INSERT INTO accounts (acct_id, cust_id, acct_status, curr_bal, credit_limit, cash_credit_limit, interest_rate, billing_cycle)
VALUES
  (1, 1, 'A', 1250.00,  5000.00,  1500.00,  0.05,  15),
  (2, 2, 'A', 3400.00, 10000.00,  3000.00,  0.05,  5),
  (3, 3, 'A',  500.00,  2000.00,   500.00,  0.05,  25);

-- Seed cards linked to accounts
INSERT INTO cards (card_num, cust_id, acct_id, card_status, exp_date, name_on_card, primary_flag)
VALUES
  ('4111111111111111', 1, 1, 'A', '1225', 'JOHN SMITH', 'Y'),
  ('5111111111111111', 2, 2, 'A', '0626', 'JANE JOHNSON', 'Y'),
  ('3111111111111111', 3, 3, 'A', '0327', 'BOB WILLIAMS', 'Y');

-- Seed transaction type reference
INSERT INTO tran_types (tran_type, tran_type_desc)
VALUES
  ('01', 'Purchase'),
  ('02', 'Cash Advance'),
  ('03', 'Payment'),
  ('04', 'Fee'),
  ('05', 'Interest'),
  ('06', 'Adjustment');

INSERT INTO tran_categories (tran_type_cd, tran_cat_cd, tran_cat_desc)
VALUES
  ('01', '01', 'Retail Purchase'),
  ('01', '02', 'Online Purchase'),
  ('02', '01', 'ATM Withdrawal'),
  ('03', '01', 'ACH Payment'),
  ('04', '01', 'Annual Fee'),
  ('05', '01', 'Daily Interest');
```

## COMP-3 Handling (if detected)

When COMP-3 fields are detected in the source code (as in CardDemo Sub-App 1 COPAUA0C), generate V4 migration:

```sql
-- V4__comp3_migration.sql
-- Source: COPAUA0C.cbl — COMP-3 fields:
--   WS-AVAILABLE-AMT: S9(13)V99 COMP-3 → NUMERIC(15,2)
--   WS-TRANSACTION-AMT: S9(10)V99 COMP-3 → NUMERIC(12,2)

ALTER TABLE auth_detail
    ALTER COLUMN transaction_amt TYPE NUMERIC(15,2);

ALTER TABLE auth_summary
    ALTER COLUMN credit_limit TYPE NUMERIC(15,2),
    ALTER COLUMN credit_balance TYPE NUMERIC(15,2),
    ALTER COLUMN approved_auth_amt TYPE NUMERIC(15,2),
    ALTER COLUMN declined_auth_amt TYPE NUMERIC(15,2);
```

## Table-to-VSAM Traceability Matrix

| PostgreSQL Table | VSAM File | COPYBOOK | Key | FKs |
|-----------------|-----------|----------|-----|-----|
| customers | CUSTDATA | CVCUS01Y | cust_id | — |
| accounts | ACCTDATA | CVACT01Y | acct_id | customers(cust_id) |
| cards | CARDDATA | CVACT02Y | card_num | customers, accounts |
| card_xref | CARDXREF | CVACT03Y | card_num | cards, customers, accounts |
| transactions | TRANSACT | CVTRA01Y | tran_id | cards, accounts, tran_types |
| tran_types | TRANTYPE | CVTRA03Y | tran_type | — |
| tran_categories | TRANCATG | CVTRA02Y | composite | — |
| discount_groups | DISCGRP | CVTRA04Y | composite | — |
| tcat_balances | TCATBALF | CVTRA05Y | composite | accounts |
| users | USRSEC | CVTRA07Y | user_id | — |
| auth_summary | IMS PAUTSUM0 | CIPAUSMY | acct_id | — |
| auth_detail | IMS PAUTDTL0 | CIPAUDTY | auth_id | auth_summary(acct_id) |
| db2_tran_types | DB2 TRANSACTION_TYPE | DB2 DDL | tran_type | — |
| db2_tran_categories | DB2 TRAN_CATEGORY | DB2 DDL | composite | — |

## Execution Steps

### Step 1: Collect All Data Sources

From Phase 2 (VSAM) + Phase 4 (COPYBOOK) + Sub-app DB2 DDL/IMS DBD:
1. List every VSAM file with key structure
2. List every DB2 table from DDL files
3. List every IMS segment from DBD files

### Step 2: Design Unified Relational Schema

1. Map COBOL PIC → PostgreSQL types
2. Design PRIMARY KEYs from VSAM key fields
3. Design FOREIGN KEY relationships
4. Map AIX to INDEXes
5. Map CHECK constraints from 88-level enums

### Step 3: Generate V1 (Tables)

CREATE TABLE for each entity, with complete column definitions.

### Step 4: Generate V2 (Constraints & Indexes)

ALTER TABLE for FOREIGN KEYs, CREATE INDEX for AIX equivalents, CHECK constraints.

### Step 5: Generate V3 (Seed Data)

INSERT statements from golden test data files.

### Step 6: Export

Write to `09-database-migrations/` directory.

## Quality Gate

- [ ] All 14+ tables have CREATE TABLE statements
- [ ] All PRIMARY KEYs match VSAM/DB2 key fields
- [ ] All FOREIGN KEYs trace back to COPYBOOK relationships
- [ ] All VSAM AIX files → PostgreSQL INDEXes
- [ ] All 88-level constraints → CHECK constraints
- [ ] COBOL PIC → SQL type mapping 100% accurate
- [ ] COMP-3 fields handled if present
- [ ] Seed data present for all lookup tables
- [ ] All SQL comments reference COBOL source
