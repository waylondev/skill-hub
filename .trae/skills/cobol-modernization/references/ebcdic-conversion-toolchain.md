# EBCDIC Encoding Conversion Toolchain

## Overview

This document provides the complete toolchain for converting EBCDIC-encoded COBOL data files to UTF-8/ASCII for Java-based migration. EBCDIC (Extended Binary Coded Decimal Interchange Code) is the native encoding on IBM z/OS mainframes, and all migrated data must be converted correctly without corruption.

## Common EBCDIC Code Pages

| Code Page | Java Charset Name | Region / Locale | Description |
|-----------|------------------|-----------------|-------------|
| IBM-037 | `IBM037` / `CP037` | US, Canada, Netherlands, Portugal, Brazil, Australia, New Zealand | CPC037, most common English EBCDIC |
| IBM-273 | `IBM273` / `CP273` | Germany, Austria | German EBCDIC (ä, ö, ü, ß) |
| IBM-277 | `IBM277` / `CP277` | Denmark, Norway | Danish/Norwegian EBCDIC (æ, ø, å) |
| IBM-278 | `IBM278` / `CP278` | Finland, Sweden | Finnish/Swedish EBCDIC (ä, ö, å) |
| IBM-280 | `IBM280` / `CP280` | Italy | Italian EBCDIC (à, è, ì, ò, ù) |
| IBM-284 | `IBM284` / `CP284` | Spain, Latin America | Spanish EBCDIC (ñ, á, é, í, ó, ú, ü) |
| IBM-285 | `IBM285` / `CP285` | United Kingdom | UK English EBCDIC (£ symbol) |
| IBM-297 | `IBM297` / `CP297` | France | French EBCDIC (à, â, ç, è, é, ê, ë, î, ï, ô, ù, û, ü) |
| IBM-500 | `IBM500` / `CP500` | International | International EBCDIC (Latin-1) |
| IBM-930 | `IBM930` / `CP930` | Japan | Japanese EBCDIC (Katakana/Kanji mixed) |
| IBM-939 | `IBM939` / `CP939` | Japan (extended) | Japanese EBCDIC extended |
| IBM-1047 | `IBM1047` / `CP1047` | Open Systems | Latin-1 EBCDIC for Unix/Linux |
| IBM-1140 | `IBM1140` / `CP1140` | US with Euro | CPC037 + Euro sign (€) |
| IBM-1141 | `IBM1141` / `CP1141` | Germany with Euro | CP273 + Euro sign (€) |
| IBM-1148 | `IBM1148` / `CP1148` | International with Euro | CP500 + Euro sign (€) |

### Code Page Detection Strategy

```java
public enum CobolCodePage {

    IBM037(37, "US/English", new byte[]{0x40, 0x5A, 0x7E, 0x6B, 0x50}),
    IBM273(273, "German", new byte[]{0x40, 0x5A, 0x7E}),
    IBM500(500, "International", new byte[]{0x40, 0x5A, 0x7E});

    private final int codePageNumber;
    private final String description;
    private final byte[] signatureBytes;

    CobolCodePage(int codePageNumber, String description, byte[] signatureBytes) {
        this.codePageNumber = codePageNumber;
        this.description = description;
        this.signatureBytes = signatureBytes;
    }

    public static CobolCodePage fromCharsetName(String charsetName) {
        String normalized = charsetName.toUpperCase()
            .replace("IBM", "").replace("CP", "");
        for (CobolCodePage cp : values()) {
            if (String.valueOf(cp.codePageNumber).equals(normalized)) {
                return cp;
            }
        }
        return IBM037;
    }

    public Charset toCharset() {
        return Charset.forName("IBM" + codePageNumber);
    }
}
```

## CLI Conversion Commands

### Linux / Unix (iconv)

```bash
# Single file conversion (IBM-037 → UTF-8)
iconv -f IBM-037 -t UTF-8 input.dat -o output.txt

# Batch conversion with progress
for f in /data/ebcdic/*.dat; do
    echo "Converting: $f"
    iconv -f IBM-037 -t UTF-8 "$f" -o "/data/utf8/$(basename "$f").txt"
done

# Verify with hex dump comparison
xxd input.dat | head -n 20
xxd output.txt | head -n 20
```

### Linux (dd command)

```bash
dd if=input.dat of=output.txt conv=ascii
```

### Windows PowerShell

```powershell
# Single file conversion
[System.Text.Encoding]::GetEncoding(37).GetString(
    [System.IO.File]::ReadAllBytes("D:\data\input.dat")
) | Out-File -FilePath "D:\data\output.txt" -Encoding UTF8

# Batch conversion script
$inputDir = "D:\data\ebcdic"
$outputDir = "D:\data\utf8"
Get-ChildItem $inputDir -Filter *.dat | ForEach-Object {
    $ebcdic = [System.IO.File]::ReadAllBytes($_.FullName)
    $utf8 = [System.Text.Encoding]::GetEncoding(37).GetString($ebcdic)
    $outPath = Join-Path $outputDir "$($_.BaseName).txt"
    [System.IO.File]::WriteAllText($outPath, $utf8, [System.Text.UTF8Encoding]::new($false))
    Write-Host "Converted: $($_.Name)"
}
```

## Java Library Conversion

### Basic Byte-Level Conversion

```java
import java.nio.charset.Charset;
import java.nio.charset.StandardCharsets;

public class EbcdicConverter {

    private final Charset sourceCharset;
    private final Charset targetCharset;

    public EbcdicConverter(String sourceCodePage) {
        this.sourceCharset = Charset.forName(sourceCodePage);
        this.targetCharset = StandardCharsets.UTF_8;
    }

    public String bytesToString(byte[] ebcdicBytes) {
        return new String(ebcdicBytes, sourceCharset);
    }

    public byte[] stringToEbcdic(String text) {
        return text.getBytes(sourceCharset);
    }

    public byte[] ebcdicToUtf8Bytes(byte[] ebcdicBytes) {
        String intermediate = new String(ebcdicBytes, sourceCharset);
        return intermediate.getBytes(targetCharset);
    }
}
```

### Streaming Conversion for Large Files

```java
import java.io.*;
import java.nio.charset.Charset;
import java.nio.charset.StandardCharsets;

public class StreamingEbcdicConverter {

    public static void convertFile(String inputPath, String outputPath,
                                    String sourceCodePage) throws IOException {
        Charset ebcdic = Charset.forName(sourceCodePage);

        try (BufferedReader reader = new BufferedReader(
                new InputStreamReader(new FileInputStream(inputPath), ebcdic));
             BufferedWriter writer = new BufferedWriter(
                new OutputStreamWriter(new FileOutputStream(outputPath), StandardCharsets.UTF_8))) {

            char[] buffer = new char[32768];
            int charsRead;
            while ((charsRead = reader.read(buffer)) != -1) {
                writer.write(buffer, 0, charsRead);
            }
        }
    }
}
```

## Record-Level EBCDIC Handling with Fixed-Length Records (COBOL FD)

COBOL File Descriptions (FD) define fixed-length records that must be parsed field by field.

### Record Layout Parser

```java
import java.nio.ByteBuffer;
import java.nio.charset.Charset;

public class CobolRecordParser {

    private final Charset ebcdicCharset;
    private final int recordLength;
    private final List<FieldDef> fieldDefs;

    public CobolRecordParser(String codePage, int recordLength, List<FieldDef> fieldDefs) {
        this.ebcdicCharset = Charset.forName(codePage);
        this.recordLength = recordLength;
        this.fieldDefs = fieldDefs;
    }

    public Map<String, Object> parseRecord(byte[] recordBytes) {
        if (recordBytes.length != recordLength) {
            throw new IllegalArgumentException("Expected " + recordLength
                + " bytes, got " + recordBytes.length);
        }

        Map<String, Object> record = new LinkedHashMap<>();
        ByteBuffer buffer = ByteBuffer.wrap(recordBytes);

        for (FieldDef field : fieldDefs) {
            byte[] fieldBytes = new byte[field.length];
            buffer.get(fieldBytes, field.offset, field.length);

            Object value = switch (field.type) {
                case DISPLAY -> new String(fieldBytes, ebcdicCharset).trim();
                case COMP_3 -> Comp3Util.unpack(fieldBytes);
                case COMP -> parseComp(fieldBytes, field.length);
                case ALPHANUMERIC -> new String(fieldBytes, ebcdicCharset);
                case HEX -> bytesToHex(fieldBytes);
            };
            record.put(field.name, value);
        }
        return record;
    }

    public record FieldDef(String name, int offset, int length, FieldType type) {}

    public enum FieldType { DISPLAY, COMP_3, COMP, ALPHANUMERIC, HEX }

    private Long parseComp(byte[] bytes, int length) {
        ByteBuffer bb = ByteBuffer.allocate(8);
        bb.position(8 - length);
        bb.put(bytes);
        bb.flip();
        return bb.getLong();
    }

    private String bytesToHex(byte[] bytes) {
        StringBuilder sb = new StringBuilder();
        for (byte b : bytes) sb.append(String.format("%02X", b));
        return sb.toString();
    }
}
```

### Example: COBOL FD → Java RecordParser

```cobol
FD  CUSTOMER-FILE
    RECORD CONTAINS 120 CHARACTERS.
01  CUSTOMER-RECORD.
    05 CUST-ID       PIC X(10).
    05 CUST-NAME     PIC X(30).
    05 CUST-BALANCE  PIC S9(7)V99 COMP-3.
    05 CUST-STATUS   PIC X(1).
    05 FILLER        PIC X(72).
```

```java
RecordParser parser = new CobolRecordParser("IBM-037", 120, List.of(
    new FieldDef("custId", 0, 10, FieldType.DISPLAY),
    new FieldDef("custName", 10, 30, FieldType.DISPLAY),
    new FieldDef("custBalance", 40, 5, FieldType.COMP_3),
    new FieldDef("custStatus", 45, 1, FieldType.DISPLAY),
    new FieldDef("filler", 46, 74, FieldType.ALPHANUMERIC)
));
```

## Hex Dump Verification

### Linux: Verify Conversion Correctness

```bash
# Dump first 256 bytes of EBCDIC original
xxd -l 256 input.dat

# Dump first 256 bytes of converted UTF-8
xxd -l 256 output.txt

# Compare byte counts
wc -c input.dat
wc -c output.txt

# Sampling random records for visual check
dd if=input.dat bs=120 skip=$((RANDOM % 1000)) count=1 | xxd
```

### Java: Hex Dump Utility

```java
public class HexDumpUtil {

    public static String hexDump(byte[] data, int maxLen) {
        StringBuilder sb = new StringBuilder();
        int len = Math.min(data.length, maxLen);

        for (int i = 0; i < len; i += 16) {
            sb.append(String.format("%08X  ", i));
            StringBuilder hex = new StringBuilder();
            StringBuilder ascii = new StringBuilder();

            for (int j = 0; j < 16 && (i + j) < len; j++) {
                int b = data[i + j] & 0xFF;
                hex.append(String.format("%02X ", b));
                ascii.append(b >= 0x20 && b < 0x7F ? (char) b : '.');
            }

            sb.append(String.format("%-48s %s%n", hex, ascii));
        }
        return sb.toString();
    }
}
```

## COMP-3: CRITICAL — MUST NOT Convert via EBCDIC→UTF-8

**WARNING:** COMP-3 (packed decimal) fields contain binary nibbles that will be irreversibly corrupted if processed through EBCDIC→UTF-8 character conversion. These fields must be extracted as raw bytes and unpacked separately.

### COMP-3 Detection and Separation

```java
public class Comp3SafeConverter {

    public static Map<String, Object> convertRecord(byte[] record,
                                                     List<FieldDef> fieldDefs,
                                                     Charset ebcdicCharset) {
        Map<String, Object> result = new LinkedHashMap<>();

        for (FieldDef field : fieldDefs) {
            byte[] fieldBytes = Arrays.copyOfRange(record, field.offset,
                field.offset + field.length);

            if (field.type == FieldType.COMP_3 || field.type == FieldType.COMP) {
                // NEVER convert binary fields through charset
                result.put(field.name + "_HEX", bytesToHex(fieldBytes));
                result.put(field.name, field.type == FieldType.COMP_3
                    ? Comp3Util.unpack(fieldBytes)
                    : parseComp(fieldBytes));
            } else {
                result.put(field.name, new String(fieldBytes, ebcdicCharset).trim());
            }
        }
        return result;
    }
}
```

## Batch Conversion Script Template

### Shell Script (Linux)

```bash
#!/bin/bash
# batch-ebcdic-convert.sh

SOURCE_CODEPAGE="${1:-IBM-037}"
INPUT_DIR="${2:-./ebcdic_input}"
OUTPUT_DIR="${3:-./utf8_output}"
LOG_FILE="conversion-$(date +%Y%m%d-%H%M%S).log"

mkdir -p "$OUTPUT_DIR"

echo "=== EBCDIC Conversion Batch ===" | tee -a "$LOG_FILE"
echo "Source: $SOURCE_CODEPAGE" | tee -a "$LOG_FILE"
echo "Input:  $INPUT_DIR" | tee -a "$LOG_FILE"
echo "Output: $OUTPUT_DIR" | tee -a "$LOG_FILE"
echo "--------------------------------" | tee -a "$LOG_FILE"

TOTAL=0
SUCCESS=0
FAILED=0

for f in "$INPUT_DIR"/*.dat "$INPUT_DIR"/*.bin; do
    [ -f "$f" ] || continue
    TOTAL=$((TOTAL + 1))
    BASENAME=$(basename "$f")
    OUTPUT="$OUTPUT_DIR/${BASENAME%.*}.txt"

    echo -n "[$TOTAL] $BASENAME ... " | tee -a "$LOG_FILE"

    if iconv -f "$SOURCE_CODEPAGE" -t UTF-8 "$f" -o "$OUTPUT" 2>>"$LOG_FILE"; then
        IN_SIZE=$(wc -c < "$f")
        OUT_SIZE=$(wc -c < "$OUTPUT")
        echo "OK (${IN_SIZE}B → ${OUT_SIZE}B)" | tee -a "$LOG_FILE"
        SUCCESS=$((SUCCESS + 1))
    else
        echo "FAILED" | tee -a "$LOG_FILE"
        FAILED=$((FAILED + 1))
    fi
done

echo "--------------------------------" | tee -a "$LOG_FILE"
echo "Total: $TOTAL, Success: $SUCCESS, Failed: $FAILED" | tee -a "$LOG_FILE"
```

### Java Batch Converter

```java
public class BatchEbcdicConverter {

    private final Charset sourceCharset;

    public BatchEbcdicConverter(String codePage) {
        this.sourceCharset = Charset.forName(codePage);
    }

    public ConversionReport convertDirectory(Path inputDir, Path outputDir) throws IOException {
        ConversionReport report = new ConversionReport();
        Files.createDirectories(outputDir);

        try (var files = Files.list(inputDir)) {
            files.filter(Files::isRegularFile).forEach(file -> {
                try {
                    ConvertResult result = convertSingleFile(file, outputDir);
                    report.add(result);
                } catch (IOException e) {
                    report.addFailed(file.getFileName().toString(), e.getMessage());
                }
            });
        }
        return report;
    }

    private ConvertResult convertSingleFile(Path inputFile, Path outputDir) throws IOException {
        byte[] ebcdicBytes = Files.readAllBytes(inputFile);
        String content = new String(ebcdicBytes, sourceCharset);

        Path outputFile = outputDir.resolve(
            inputFile.getFileName().toString().replaceAll("\\.[^.]+$", ".txt"));
        Files.writeString(outputFile, content, StandardCharsets.UTF_8);

        return new ConvertResult(inputFile.getFileName().toString(),
            ebcdicBytes.length, content.getBytes(StandardCharsets.UTF_8).length, true);
    }

    public record ConvertResult(String fileName, long inputBytes, long outputBytes, boolean success) {}
    public record FailedResult(String fileName, String error) {}

    public static class ConversionReport {
        private final List<ConvertResult> successes = new ArrayList<>();
        private final List<FailedResult> failures = new ArrayList<>();

        void add(ConvertResult r) { successes.add(r); }
        void addFailed(String name, String error) { failures.add(new FailedResult(name, error)); }
    }
}
```

## Validation Checklist

### Pre-Conversion Checks

| # | Check | Method |
|---|-------|--------|
| 1 | Confirm source code page | Check z/OS system symbols or ask mainframe team |
| 2 | Identify all input files | `find /input -name "*.dat" | wc -l` |
| 3 | Record total input bytes | `du -sh /input/` |
| 4 | Identify COMP-3 fields | From COBOL COPYBOOK analysis |
| 5 | Identify packed/binary fields | From COBOL FD statements |
| 6 | Create backup of original files | `cp -r /input /input.backup` |

### Post-Conversion Validation

| # | Check | Method |
|---|-------|--------|
| 1 | Byte count comparison | Original bytes vs UTF-8 bytes (expect increase) |
| 2 | Record count comparison | Count record delimiters / fixed-length division |
| 3 | Random sampling (min 100 records) | Extract and manually verify 100 random records |
| 4 | Field boundary verification | Check that fixed-width fields align correctly |
| 5 | Special character presence | Search for expected umlauts, accents, yen, etc. |
| 6 | COMP-3 field integrity | Compare unpacked decimal values to expected |
| 7 | Date format verification | Ensure dates parse correctly after conversion |
| 8 | Numeric field verification | Verify all numeric DISPLAY fields parse to valid numbers |
| 9 | Trailing space preservation | COBOL right-pads with spaces — verify trim behavior |
| 10 | Line ending consistency | CRLF vs LF across the converted output |

### Automated Validation Script

```java
public class ConversionValidator {

    public ValidationReport validate(Path originalFile, Path convertedFile,
                                      Charset sourceCharset, int recordLength) throws IOException {
        byte[] original = Files.readAllBytes(originalFile);
        String converted = Files.readString(convertedFile, StandardCharsets.UTF_8);

        ValidationReport report = new ValidationReport();
        report.totalOriginalBytes = original.length;
        report.totalConvertedBytes = converted.getBytes(StandardCharsets.UTF_8).length;

        int expectedRecords = original.length / recordLength;
        int actualRecords = converted.split("\n").length;
        report.recordCountMatch = expectedRecords == actualRecords;

        report.sampleVerifications = sampleVerify(original, converted,
            sourceCharset, recordLength, 100);

        return report;
    }

    private List<SampleResult> sampleVerify(byte[] original, String converted,
                                             Charset sourceCharset, int recordLength,
                                             int sampleCount) {
        int totalRecords = original.length / recordLength;
        Random random = new Random(42);
        List<SampleResult> results = new ArrayList<>();

        for (int i = 0; i < Math.min(sampleCount, totalRecords); i++) {
            int recNum = random.nextInt(totalRecords);
            byte[] origRec = Arrays.copyOfRange(original,
                recNum * recordLength, (recNum + 1) * recordLength);
            String convLine = converted.split("\n")[recNum];

            String origAsStr = new String(origRec, sourceCharset);
            results.add(new SampleResult(recNum,
                origAsStr.trim().equals(convLine.trim())));
        }
        return results;
    }

    public record SampleResult(int recordNumber, boolean matches) {}

    public static class ValidationReport {
        public long totalOriginalBytes;
        public long totalConvertedBytes;
        public boolean recordCountMatch;
        public List<SampleResult> sampleVerifications;
    }
}
```

## Integration Notes

- Referenced by: quality-checklist.md check 18 (COMP-3 Coverage), SKILL.md Phase 2 (VSAM/Data analysis), cobol-to-java-mappings.md (Data type conversions), assembler-replacement.md (binary field handling)
- Last reviewed: 2026-05-04
