# Phase 15: COBOL Dialect Support

## Objective

Identify which COBOL dialect(s) the legacy system uses and apply dialect-specific analysis and conversion rules. Different COBOL compilers implement different extensions, intrinsic functions, and runtime behaviors. Correct dialect identification is essential for accurate logic extraction and faithful Java translation.

## Input

- Phase 0: Environment Discovery — compiler identification from JCL/compile listings
- Phase 1: Source Inventory — program file headers and compiler directives
- Phase 5: Logic Extraction — dialect affects statement interpretation

## Supported Dialects

### 1. IBM Enterprise COBOL (z/OS) — Most Common

**Key differences from standard COBOL:**

| Feature | IBM Enterprise COBOL Behavior | Java Translation Strategy |
|---------|------------------------------|--------------------------|
| SQL coprocessor | `EXEC SQL ... END-EXEC` embedded directly in COBOL, compiled by DB2 preprocessor | Extract SQL → Spring Data JPA Repository queries. DB2-specific SQL (CURSOR WITH HOLD, OPTIMIZE FOR N ROWS) → PostgreSQL equivalents |
| CICS commands | `EXEC CICS ... END-EXEC` — READ/WRITE/DELETE/STARTBR/READNEXT/SEND MAP | Map each CICS command to Repository methods (Phase 2) or Controller endpoints (Phase 3) |
| VSAM file access | IDCAMS DD statements in JCL → KSDS/ESDS/RRDS file access via CICS File Control | KSDS → @Id indexed table, ESDS → sequential table, RRDS → table with explicit RRN column |
| COMP-3 packed decimal | `PIC S9(15)V99 COMP-3` — mainframe native packed BCD | Convert to `BigDecimal` with exact `precision` and `scale` in `@Column` annotation |
| EBCDIC character set | All `PIC X` fields are EBCDIC-encoded on disk | Apply EBCDIC→UTF-8 conversion during data migration. All Java strings are UTF-16/UTF-8 |
| RETURN-CODE special register | Set at program exit, checked by calling program or JCL COND parameter | Map to Java method return value (int/ResponseEntity HTTP status) |
| SORT/MERGE verbs | DFSORT/ICETOOL invoked via JCL or COBOL `SORT` statement | Replace with Spring Batch `SortStep` or PostgreSQL `ORDER BY` |
| `CBL` compiler directives | `CBL LIB,QUOTE,NODYNAM` — affects linkage, quoting, subprogram calls | Analyze directive to determine subprogram linkage → Spring `@Service` dependencies |

### 2. Micro Focus COBOL (Windows/Linux)

**Key differences from standard COBOL:**

| Feature | Micro Focus Behavior | Java Translation Strategy |
|---------|---------------------|--------------------------|
| File handling | `SELECT ... ASSIGN TO [filename]` with runtime `extfh.cfg` configuration. Supports line-sequential, record-sequential, indexed files | Use Spring Batch `FlatFileItemReader` for sequential, JPA Entity for indexed. Configuration-driven file paths via `application.yml` |
| Screen Section | Native `SCREEN SECTION` for terminal I/O (non-CICS). `ACCEPT/DISPLAY` with AT clause for positioning | Map to REST Controllers — each `ACCEPT` = `@RequestBody` field, each `DISPLAY` = Response DTO field. SCREEN SECTION → React/Angular component layout |
| Call-by-value extensions | `CALL ... USING BY VALUE` — non-standard parameter passing | Replace with standard Java method invocation. `BY VALUE` = normal parameter, `BY REFERENCE` = mutable wrapper object |
| OO COBOL extensions | `CLASS-ID`, `METHOD-ID`, `FACTORY` — Micro Focus native OOP | Direct mapping to Java classes. `CLASS-ID` → `class`, `METHOD-ID` → method, `FACTORY` → `static` methods |
| Animator debugger | Interactive source-level debugger for runtime debugging | Replace with IntelliJ IDEA debugger, remote debugging (Phase 14) |

### 3. Hitachi COBOL (Mainframe)

**Key differences from standard COBOL:**

| Feature | Hitachi Behavior | Java Translation Strategy |
|---------|-----------------|--------------------------|
| Japanese character support | Built-in double-byte (`PIC N`) and shift-JIS/EUC encoding. `FUNCTION DISPLAY-OF` for EBCDIC↔JIS conversion | Use Java UTF-16 String natively. `PIC N(10)` → `@Column(length=20)` for double-byte storage. Apply ICU4J for legacy encoding conversion |
| HI-UX/MP environment | Hitachi mainframe OS with proprietary file system and job scheduler | Replace JCL scheduler with Spring Batch + Cron or enterprise scheduler (Control-M/Autosys). File system → Linux mount or S3 |
| Extended `INSPECT` | `INSPECT ... CONVERTING` with extended code-page tables | Map to Java `String.translateEscapes()` or Apache Commons Text character mapping |
| Database integration (XDM/RD) | Hitachi relational database with embedded SQL preprocessor | SQL → Spring Data JPA (same strategy as DB2 for IBM dialect) |

### 4. Fujitsu COBOL (NetCOBOL)

**Key differences from standard COBOL:**

| Feature | Fujitsu Behavior | Java Translation Strategy |
|---------|-----------------|--------------------------|
| Windows GUI integration | `@PowerCOBOL` GUI controls, Form Designer, ActiveX integration | Replace GUI with React/Angular SPA (Phase 10). Form → React component, control events → REST POST handlers |
| COM/ActiveX interop | `INVOKE` verb to call COM objects, OLE automation | Replace COM calls with REST/gRPC service calls or Java native libraries |
| .NET integration (NetCOBOL for .NET) | COBOL compiled to IL, runs on CLR, interop with C# assemblies | Java does not run on CLR. Extract business logic into Java services. .NET interop → REST API bridge or shared database |
| Database (`@SQL`) | Embedded SQL with ODBC providers (SQL Server, Oracle, MS Access) | SQL → Spring Data JPA Repository queries. ODBC connection string → `application.yml` DataSource config |

### 5. ACUCOBOL (extend)

**Key differences from standard COBOL:**

| Feature | ACUCOBOL Behavior | Java Translation Strategy |
|---------|------------------|--------------------------|
| ACUCOBOL-GT runtime | `cblconfig` file, `runtime.cfg`, GUI screen painter, Vision indexed files | Vision file → JPA Entity with `@Table(indexes = {...})`. GUI painter screens → React/Angular components |
| XML extensions | `C$XML` library for XML parse/generate within COBOL programs | Replace with Jackson XML mapper or standard SAX/DOM parsers in Java |
| Web runtime (ACUCOBOL-GT Web) | COBOL program served via CGI/ISAPI as web application | Replace with Spring Boot REST API (Phase 8-9). No CGI bridge needed |
| `ACCEPT ... FROM ESCAPE KEY` | Full keyboard event handling beyond standard PF keys | Map to JavaScript `onKeyDown` event handlers in React/Angular (Phase 10) |

### 6. GnuCOBOL (Open Source)

**Key differences from standard COBOL:**

| Feature | GnuCOBOL Behavior | Java Translation Strategy |
|---------|------------------|--------------------------|
| `STANDARD` vs. `IBMCOMP` mode | `-std=ibm` flag emulates IBM behavior, `-std=cobol85` for strict standard | If `-std=ibm`, use IBM Enterprise mapping above. If `-std=default/cobol85`, fewer proprietary extensions to handle |
| Native C interop | `CALL STATIC "c_function"` — direct C library linking | Replace C calls with Java native library (JNI) or find pure-Java equivalent library |
| Report Writer (RW) | `REPORT SECTION` with `GENERATE`/`TERMINATE` for formatted reports | Replace with JasperReports, Apache POI (Excel), or iText (PDF). Report layout → Jasper template |
| Screen I/O (non-CICS) | `SCREEN SECTION` and extended `ACCEPT/DISPLAY` for terminal UIs | Map to REST API as with Micro Focus above |

## Dialect Auto-Detection

The dialect is automatically determined from Phase 0/1 discovery. Priority order:

1. **JCL Job Cards**: `//STEPLIB DD DSN=CICSTS53.CICS.SDFHLOAD` → IBM Enterprise (CICS)
2. **Compiler Directives**: `CBL LIB` → IBM, `$SET` directives → Micro Focus, `>>SOURCE FORMAT` → GnuCOBOL
3. **COPYBOOK Headers**: `* (C) IBM CORP` → IBM, `* MICRO FOCUS` → Micro Focus
4. **Program First Lines**: `PROCESS NOSEQUENCE` → Fujitsu, `IDENTIFICATION DIVISION.` with non-standard PROGRAM-ID → varies

## Execution Steps

### Step 1: Identify Dialect

Read Phase 0/1 documents. Match compiler-identifying patterns from the auto-detection rules. Record the dialect in `15-cobol-dialects/dialect-identification.md`.

### Step 2: Document Dialect-Specific Features

For each identified dialect, create a feature inventory:
- Extensions used (SQL coprocessor, CICS, Screen Section, COM calls, etc.)
- Non-standard intrinsic functions called
- Compiler directives affecting behavior
- Encoding specifics (EBCDIC vs. ASCII vs. Shift-JIS)

### Step 3: Apply Dialect-Specific Translation Rules

Using the mapping tables above, annotate each translation in the code generation (Phase 9) with dialect-specific source references. Example:

```java
// Source: program.cbl (IBM Enterprise COBOL), EXEC CICS READ FILE('ACCTFILE')
// IBM Dialect: KSDS VSAM file, EBCDIC encoding, COMP-3 packed fields
@Lock(LockModeType.PESSIMISTIC_WRITE)
@Query("SELECT a FROM Account a WHERE a.id = :id")
Optional<Account> findByIdForUpdate(@Param("id") String id);
```

### Step 4: Generate Dialect Cross-Reference

Produce `15-cobol-dialects/dialect-cross-reference.md` — a table linking each COBOL source file to its dialect and listing every dialect-specific feature that affects translation.

## Quality Gate

- [ ] Dialect correctly identified for every COBOL source file
- [ ] Dialect-specific features inventoried (CICS, SQL, SCREEN SECTION, COM calls, etc.)
- [ ] Encoding (EBCDIC/ASCII/Shift-JIS) documented per file
- [ ] Dialect-to-Java mapping rules applied in all generated code
- [ ] Non-standard intrinsic functions identified and replacement strategy documented
- [ ] Cross-reference table complete for all programs
- [ ] GnuCOBOL `-std` flag documented if applicable
- [ ] `_state-snapshot.json` updated to `{'phase':15,'status':'complete'}`
