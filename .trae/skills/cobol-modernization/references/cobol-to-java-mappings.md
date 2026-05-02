# COBOL → Java Mapping Reference

## Data Type Mapping

### PIC Clause → Java Type

| COBOL PIC | Pattern | Java Type | JPA Column | Notes |
|-----------|---------|-----------|------------|-------|
| 9(N) N≤9 | Integer range | Integer | Integer | Direct parse |
| 9(N) N>9 | Long range | Long | Long | Direct parse |
| 9(N) with leading zeros | Fixed-width ID | String | length=N | Preserve leading zeros |
| S9(N)V99 | Decimal money | BigDecimal | precision=N+2,scale=2 | NEVER use double/float |
| S9(N)V9(N) | High precision decimal | BigDecimal | precision=N+M,scale=M | |
| X(N) date YYYYMMDD | Date string | LocalDate | DateTimeFormatter.ofPattern("yyyyMMdd") | |
| X(N) date DD-MM-YYYY | Date string | LocalDate | DateTimeFormatter.ofPattern("dd-MM-yyyy") | |
| X(N) timestamp | Timestamp | LocalDateTime | DateTimeFormatter | |
| X(N) general text | Text field | String | length=N | trim() trailing spaces |
| X(01) Y/N flag | Boolean flag | String | length=1 | Map Y→true, N→false |
| OCCURS n TIMES | Fixed array | List<T> | @ElementCollection | n separate records |

### COMP / COMP-3 Usage → Java Type

| COBOL Usage | Storage | Java Type | Unpack Method |
|-------------|---------|-----------|--------------|
| COMP-3 S9(7)V99 | 5 bytes | BigDecimal | Comp3Converter.unpack(bytes, 2) |
| COMP-3 S9(10)V99 | 7 bytes | BigDecimal | Comp3Converter.unpack(bytes, 2) |
| COMP-3 S9(15)V99 | 9 bytes | BigDecimal | Comp3Converter.unpack(bytes, 2) |
| COMP 9(4) | 2 bytes (halfword) | Integer | ByteBuffer.wrap(bytes).getShort() |
| COMP 9(9) | 4 bytes (fullword) | Integer | ByteBuffer.wrap(bytes).getInt() |
| COMP 9(18) | 8 bytes (doubleword) | Long | ByteBuffer.wrap(bytes).getLong() |

COMP-3 storage bytes: `(total_digits + 1) / 2` rounded up

### REDEFINES → Java Pattern

| COBOL Pattern | Java Solution |
|---------------|--------------|
| Type discriminator: `05 A PIC X(1). 05 B REDEFINES A ...` | `@Inheritance(strategy=SINGLE_TABLE)` + `@DiscriminatorColumn` |
| Alternate format: `05 RAW-DATA PIC X(50). 05 PARSED REDEFINES RAW ...` | Two DTOs, choose based on type flag |
| Variable-length: `05 SHORT PIC X(20). 05 LONG REDEFINES SHORT PIC X(100)` | Single Entity with nullable fields |

### OCCURS → Java Pattern

| COBOL Pattern | Java Solution |
|---------------|--------------|
| `OCCURS 5 TIMES` | `List<Detail> details = new ArrayList<>(5)` |
| `OCCURS DEPENDING ON COUNT` | `List<Item>` with dynamic size validation |
| Nested OCCURS | `List<Group>` each with `List<Item>` |

### 88-Level Condition → Java Enum

| COBOL | Java |
|-------|------|
| `05 ACCT-STATUS PIC X(1). 88 ACCT-ACTIVE VALUE 'A'. 88 ACCT-INACTIVE VALUE 'I'.` | `enum AccountStatus { ACTIVE("A"), INACTIVE("I") }` |
| `05 USER-TYPE PIC X(1). 88 IS-ADMIN VALUE 'A'. 88 IS-USER VALUE 'U'.` | `enum UserType { ADMIN("A"), USER("U") }` |
| `05 FLAG PIC X(1). 88 IS-TRUE VALUE 'Y'. 88 IS-FALSE VALUE 'N'.` | `enum YesNoFlag { YES("Y"), NO("N") }` |

## Program Classification

| Program Type | Detection Criteria |
|-------------|-------------------|
| CICS Online | Contains: EXEC CICS, DFHCOMMAREA, BMS Map name reference |
| Batch | Contains: SELECT/ASSIGN, sequential file I/O, NO EXEC CICS |
| IMS/DB2 | Contains: EXEC DLI or EXEC SQL statements |
| Utility | Contains: CALL statements, minimal file I/O |

## CICS Command → Spring Equivalent

| CICS Command | Spring Equivalent | Notes |
|-------------|------------------|------|
| EXEC CICS RETURN | return ResponseEntity | End request |
| EXEC CICS LINK | @Autowired service.call() | Program call |
| EXEC CICS XCTL | Redirect/forward | Transfer control |
| EXEC CICS START | @Scheduled / REST call | Start transaction |
| EXEC CICS RECEIVE | @RequestBody | Get input |
| EXEC CICS SEND | ResponseEntity | Send output |
| EXEC CICS READ | repository.findById() | Read VSAM |
| EXEC CICS WRITE | repository.save() | Write |
| EXEC CICS REWRITE | repository.save() | Update |
| EXEC CICS DELETE | repository.delete() | Delete |
| EXEC CICS GETMAIN | new Object() | Get storage |
| EXEC CICS FREEMAIN | GC / null | Free storage |
| EXEC CICS SYNCPOINT | @Transactional commit | Commit |
| EXEC CICS SYNCPOINT ROLLBACK | @Transactional rollback | Rollback |
| EXEC CICS WAIT | Thread.sleep() | Wait |
| EXEC CICS DELAY | Thread.sleep() | Delay |
| EXEC CICS ASKTIME | LocalDateTime.now() | Get time |
| EXEC CICS FORMATTIME | DateTimeFormatter.format() | Format time |
| EXEC CICS WRITEQ TD | log.info() / log.error() | Write TD queue |
| EXEC CICS READQ TD | Read from queue | Read TD queue |
| EXEC CICS PUT CONTAINER | Model.addAttribute() | Store container |
| EXEC CICS GET CONTAINER | @ModelAttribute | Read container |

## COBOL File Operation → JPA Repository

| COBOL | Java | Notes |
|-------|------|------|
| READ file INTO record | repository.findById(id) | Check file status |
| READ file NEXT | repository.findAll(pageable) | Sequential scan |
| WRITE record | repository.save(entity) | New record |
| REWRITE record | repository.save(entity) | Update existing |
| DELETE record | repository.delete(entity) | Remove |
| START file KEY >= | repository.findByXGreaterThan() | Positioned read |
| STARTBR + READNEXT | findAll(Pageable) | Browse sequential |
| STARTBR + READPREV | findAll(Sort.by(DESC)) | Browse reversed |

## COBOL Business Logic → Java Service

| COBOL | Java | Notes |
|-------|------|------|
| COMPUTE A = B + C | a = b.add(c) | BigDecimal |
| COMPUTE A = B - C | a = b.subtract(c) | BigDecimal |
| COMPUTE A = B * C | a = b.multiply(c) | BigDecimal |
| COMPUTE A = B / C | a = b.divide(c, scale, RoundingMode.HALF_UP) | Specify rounding |
| ADD A TO B | b = b.add(a) | Accumulator |
| SUBTRACT A FROM B | b = b.subtract(a) | Reduction |
| MULTIPLY A BY B | result = a.multiply(b) | |
| DIVIDE A BY B GIVING C | c = a.divide(b, scale, HALF_UP) | |
| EVALUATE field WHEN 'A' | switch(field) { case "A": | String comparison |
| IF A > B THEN ... ELSE | if(a.compareTo(b) > 0) | BigDecimal comparison |
| IF A = B AND C = D | if(a.equals(b) && c.equals(d)) | Compound |
| IF A = B OR C = D | if(a.equals(b) \|\| c.equals(d)) | Compound |
| PERFORM UNTIL EOF | while(!eof) or stream | Batch processing |
| PERFORM VARYING i FROM 1 BY 1 | for(int i=1; i<=n; i++) | Counter |
| PERFORM n TIMES | for(int i=0; i<n; i++) | Fixed iterations |
| PERFORM ... THRU ... | method call | Paragraph call |

## COBOL Validation → Bean Validation

| COBOL IF Condition | Java Validation |
|-------------------|----------------|
| IF field = SPACES | @NotBlank |
| IF field NOT NUMERIC | @Pattern(regexp="^\\d+$") |
| IF field < 0 | @DecimalMin("0") |
| IF field > limit | @DecimalMax |
| IF date < current | @Past / @PastOrPresent |
| IF date > current | @Future / @FutureOrPresent |

## COBOL Error Handling → Java Exception

| COBOL | Java Exception |
|-------|--------------|
| INVALID KEY / NOTFND | .orElseThrow(() -> new NotFoundException()) |
| DUPKEY on WRITE | catch DataIntegrityViolationException |
| AT END | End-of-stream handling |
| FILE STATUS = '10' | EndOfFileException |
| MOVE '999' TO ABEND CODE | throw new RuntimeException() |
| DISPLAY 'ERROR' + GOBACK | log.error() + return |

## VSAM → JPA Mapping

| VSAM Type | ORGANIZATION | JPA Equivalent |
|-----------|-------------|----------------|
| KSDS | INDEXED | @Entity with @Id |
| ESDS | SEQUENTIAL | @Entity (surrogate key) |
| RRDS | RELATIVE | @Entity with composite key |

Access Mode Mapping:
- RECORD KEY → @Id field
- ALTERNATE RECORD KEY → @Index / alternate lookup
- ACCESS MODE IS RANDOM → findById() supported
- ACCESS MODE IS SEQUENTIAL → findAll() with pagination
- ACCESS MODE IS DYNAMIC → Both random and sequential

## JCL Element → Spring Batch

| JCL Element | Spring Batch Equivalent |
|-------------|------------------------|
| JOB card | @SpringBootApplication name |
| EXEC PGM=program | Step bean definition |
| DD DSN=input.file | FlatFileItemReader / JdbcCursorItemReader |
| DD DSN=output.file | FlatFileItemWriter / JdbcBatchItemWriter |
| DD DSN=*.sysout | Tasklet logging |
| COND=(code,NE) | Skip/retry policy |
| GDG(+n) | Partition by date/version |
| DISP=(NEW,CATLG) | Resource handling strategy |

## JCL COND → Spring Batch Error Handling

| JCL COND | Spring Batch |
|----------|--------------|
| COND=(0,NE) | Execute if previous step succeeded |
| COND=(4,LT) | Skip if RC < 4 |
| COND=(8,GE) | Retry if RC >= 8 |

## JCL Utility → Java Replacement

| JCL Utility | Function | Java Replacement |
|-------------|----------|-----------------|
| IDCAMS | VSAM define/delete/alter | Flyway migration scripts |
| IEBGENER | Sequential file copy | FileCopyUtils / Spring Batch |
| IEFBR14 | Dummy step | Remove or log |
| SORT | Sort/merge files | Stream.sorted() / Spring Batch sort |
| DSNTEP4 | DB2 SQL execution | JdbcTemplate / repository |
| DSNTIAUL | DB2 unload | Spring Batch JdbcCursorItemReader |
| FTP | File transfer | SftpSessionFactory / REST upload |
| TXT2PDF | Text to PDF | iText / Apache PDFBox |

## PF Key → HTTP Method

| PF Key | COBOL Check | HTTP Method | Action |
|--------|------------|-------------|--------|
| ENTER | EIBAID = DFHENTER | POST/PUT | Submit |
| F3 | EIBAID = DFHPF3 | GET | Exit/Return |
| F4 | EIBAID = DFHPF4 | - | Clear/Reset |
| F5 | EIBAID = DFHPF5 | POST | Save |
| F7 | EIBAID = DFHPF7 | GET | Page backward |
| F8 | EIBAID = DFHPF8 | GET | Page forward |
| F12 | EIBAID = DFHPF12 | - | Cancel |

## RACF → Spring Security

| RACF Element | Spring Security Equivalent |
|--------------|---------------------------|
| RACF Profile | @PreAuthorize("hasRole('...')") |
| Resource Class | Row-level security (@PostFilter) |
| User ID/Password | BCryptPasswordEncoder + UserDetailsService |
| Transaction Auth | Method security (@PreAuthorize) |

## Assembler → Java Replacement

| Assembler Program | Function | Java Replacement |
|-------------------|----------|-----------------|
| COBDATFT | Date format conversion | DateTimeFormatter |
| MVSWAIT | Timer/sleep control | Thread.sleep() |
| CEE3ABD | ABEND | throw new RuntimeException() |
| CEELOCT | Get current timestamp | LocalDateTime.now() |

## EBCDIC Code Pages

| Code Page | Description | Usage |
|-----------|-------------|-------|
| IBM-037 | US/Canada EBCDIC | Most common |
| IBM-273 | Germany/Austria | European |
| IBM-277 | Denmark/Norway | Nordic |
| IBM-278 | Finland/Sweden | Nordic |
| IBM-500 | International EBCDIC | Multi-language |
| IBM-930 | Japanese Katakana/Kanji | Japanese |
