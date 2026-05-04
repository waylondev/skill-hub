# Assembler Replacement Reference

## Overview

When COBOL programs call assembler utilities (via `CALL 'ASMPGM'`), these must be replaced with Java equivalents. This document provides the replacement patterns for common mainframe assembler utilities.

## Common Assembler Call Patterns

### Detection

```cobol
* Assembler calls in COBOL programs
CALL 'ASMPGM' USING WS-INPUT WS-OUTPUT.
CALL 'CBLTDLI' USING ...           /* IMS DL/I call
CALL 'IGZSMSG' USING ...           /* Sort merge utility
CALL 'CEETDLI' USING ...           /* Language Environment
```

## Replacement Patterns

| Assembler Program | Purpose | Java Replacement | Implementation |
|-------------------|---------|------------------|----------------|
| `IGZSMSG` / `ICE` / `DFSORT` | Sort/merge | `Stream.sorted()` or `Collections.sort()` | `Comparator.comparing()` |
| `CEEBET` / `CEEDAT` | Date/time formatting | `DateTimeFormatter` | `LocalDateTime.now().format()` |
| `CEEMRBR` / `CEEMOVE` | Memory copy/move | `System.arraycopy()` or `ByteBuffer` | Direct Java API |
| `CEESTRNG` | String manipulation | `String` methods / `StringUtils` | `substring()`, `replace()`, etc. |
| `CEEDIV` / `CEEADD` | Arithmetic operations | `BigDecimal` methods | `divide()`, `add()`, etc. |
| `CBLTDLI` / `DFSDLTL` | IMS DL/I calls | JPA Repository methods | See IMS migration guide |
| `DSNHLI` / `DSNHLIR` | DB2 Call Attach | JPA EntityManager | Native query or JPA |
| `CSVQSRV` / `IEFBR14` | System service | `System.getenv()` / config | Spring `@Value` or `Environment` |
| `STIMER` / `STXIT` | Timer/interrupt | `ScheduledExecutorService` | `scheduleAtFixedRate()` |
| `IEBCOMPR` / `IEBGENER` | File copy/compare | `Files.copy()` / `Files.mismatch()` | Java NIO |

## Detailed Replacements

### Sort/Merge (IGZSMSG/DFSORT → Java Streams)

**COBOL/Assembler Pattern:**
```cobol
CALL 'IGZSMSG' USING SORT-CONTROL WS-SORT-FILE.
SORT WS-FILE ON ASCENDING KEY SORT-KEY.
```

**Java Replacement:**
```java
// Source: SORT WS-FILE ON ASCENDING KEY SORT-KEY
// Replaced: CALL 'IGZSMSG' (DFSORT) → Stream.sorted()

List<Record> sorted = records.stream()
    .sorted(Comparator.comparing(Record::getSortKey))
    .collect(Collectors.toList());

// For descending sort
List<Record> sortedDesc = records.stream()
    .sorted(Comparator.comparing(Record::getSortKey).reversed())
    .collect(Collectors.toList());

// For composite sort (multi-key)
List<Record> multiSorted = records.stream()
    .sorted(Comparator.comparing(Record::getKey1)
        .thenComparing(Record::getKey2)
        .thenComparing(Record::getKey3))
    .collect(Collectors.toList());
```

### Date/Time (CEEDAT → DateTimeFormatter)

**COBOL/Assembler Pattern:**
```cobol
CALL 'CEEDAT' USING WS-TOKEN 'YYYYMMDD' WS-OUTPUT.
```

**Java Replacement:**
```java
// Source: CALL 'CEEDAT' (date formatting) → DateTimeFormatter

DateTimeFormatter formatter = DateTimeFormatter.ofPattern("yyyyMMdd");
String formatted = LocalDate.now().format(formatter);

// For timestamp: 'YYYYMMDDHHMMSS'
DateTimeFormatter tsFormatter = DateTimeFormatter.ofPattern("yyyyMMddHHmmss");
String timestamp = LocalDateTime.now().format(tsFormatter);
```

### String Operations (CEESTRNG → Java String)

**COBOL/Assembler Pattern:**
```cobol
CALL 'CEESTRNG' USING WS-STRING WS-LENGTH.
```

**Java Replacement:**
```java
// Source: CALL 'CEESTRNG' (string length) → String.length()

int length = str.length();
String trimmed = str.trim();
String substring = str.substring(start, end);
String replaced = str.replace(oldChar, newChar);

// For UNSTRING (COBOL statement)
String[] parts = str.split(delimiter);
```

## Spring Batch Sort Integration

When DFSORT is used in batch JCL steps:

```java
@Bean
public Step sortStep() {
    return stepBuilderFactory.get("sortStep")
        .<InputRecord, OutputRecord>chunk(100)
        .reader(reader())
        .processor(record -> record)  // Pass-through
        .writer(sortWriter())
        .build();
}

@Bean
public ItemWriter<OutputRecord> sortWriter() {
    return items -> {
        List<OutputRecord> sorted = items.stream()
            .sorted(Comparator.comparing(OutputRecord::getKey))
            .collect(Collectors.toList());
        // Write sorted records
        repository.saveAll(sorted);
    };
}
```

## Assembler Replacement Checklist

- [ ] All `CALL 'ASM*` statements identified in Phase 1
- [ ] Each assembler call mapped to Java equivalent
- [ ] Sort operations replaced with Stream.sorted()
- [ ] Date formatting replaced with DateTimeFormatter
- [ ] Memory operations replaced with System.arraycopy() or ByteBuffer
- [ ] String operations replaced with Java String methods
- [ ] IMS DL/I calls replaced with JPA (see IMS migration guide)
- [ ] DB2 calls replaced with JPA/Native queries
- [ ] System service calls replaced with Spring configuration
- [ ] Timer/interrupt replaced with ScheduledExecutorService
- [ ] File operations replaced with Java NIO

## Common Pitfalls

| Pitfall | Assembler Behavior | Java Default | Correct Approach |
|---------|-------------------|-------------|-----------------|
| String truncation | Fixed-length, space-padded | Variable length | `String.format("%-80s", value)` if padding needed |
| Numeric overflow | Silent truncation | ArithmeticException | Validate before operation, use BigDecimal |
| EBCDIC vs ASCII | EBCDIC encoding | UTF-8 | Use EBCDIC→UTF-8 conversion utility |
| Binary sort order | EBCDIC collation | Unicode collation | Use `Collator.getInstance(Locale.forLanguageTag("en-US"))` |
| Record alignment | Natural boundary alignment | No alignment needed | Use `ByteBuffer` if alignment matters |
