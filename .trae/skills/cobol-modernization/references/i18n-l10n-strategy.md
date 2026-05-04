# I18N / L10N Internationalization Strategy

## Overview

This document defines the strategy for extracting, migrating, and managing internationalization (i18n) and localization (l10n) content from COBOL mainframe applications to Java Spring Boot. COBOL applications typically hardcode messages in DISPLAY statements, BMS maps, and MOVE statements — all of which must be externalized into Spring MessageSource properties files.

## Message Extraction from COBOL Source

### Extraction Patterns

| COBOL Source Pattern | Example | Extraction Regex |
|---------------------|---------|-----------------|
| `DISPLAY 'message'` | `DISPLAY 'ERR001: INVALID INPUT'` | `DISPLAY\s+'([^']+)'` |
| `MOVE 'literal' TO variable` | `MOVE 'RECORD NOT FOUND' TO WS-ERROR-MSG` | `MOVE\s+'([^']+)'\s+TO` |
| `STRING 'literal' DELIMITED BY ...` | `STRING 'ACCOUNT:' DELIMITED BY SIZE` | `STRING\s+'([^']+)'` |
| BMS `DFHMDF ... INITIAL='text'` | `DFHMDF ... INITIAL='Customer Name:'` | `INITIAL='([^']+)'` |
| `SET ... TO 'literal'` | `SET WS-MSG TO 'PROCESSING COMPLETE'` | `SET\s+\S+\s+TO\s+'([^']+)'` |
| `CALL ... USING 'literal'` | `CALL 'ERRRTN' USING 'FILE-OPEN-ERR'` | Error message codes |

### Automated Message Extraction Script

```java
import java.io.*;
import java.nio.file.*;
import java.util.*;
import java.util.regex.*;

public class CobolMessageExtractor {

    private static final Pattern DISPLAY_PATTERN =
        Pattern.compile("DISPLAY\\s+'([^']+)'|DISPLAY\\s+\"([^\"]+)\"");
    private static final Pattern MOVE_PATTERN =
        Pattern.compile("MOVE\\s+'([^']+)'\\s+TO\\s+(\\S+)");
    private static final Pattern STRING_PATTERN =
        Pattern.compile("STRING\\s+'([^']+)'");
    private static final Pattern BMS_INITIAL_PATTERN =
        Pattern.compile("INITIAL='([^']+)'");
    private static final Pattern SET_PATTERN =
        Pattern.compile("SET\\s+(\\S+)\\s+TO\\s+'([^']+)'");

    public ExtractedMessages extract(Path cobolSourceDir) throws IOException {
        ExtractedMessages result = new ExtractedMessages();
        int messageCounter = 0;

        try (var files = Files.walk(cobolSourceDir)) {
            files.filter(f -> f.toString().endsWith(".cbl")
                       || f.toString().endsWith(".cob")
                       || f.toString().endsWith(".cpy")
                       || f.toString().endsWith(".bms"))
                 .forEach(file -> processFile(file, result));
        }
        return result;
    }

    private void processFile(Path file, ExtractedMessages result) {
        try {
            String content = Files.readString(file);
            String fileName = file.getFileName().toString();

            for (Matcher m = DISPLAY_PATTERN.matcher(content);
                 m.find(); ) {
                String msg = m.group(1) != null ? m.group(1) : m.group(2);
                String key = generateKey(fileName, "DISPLAY", msg);
                result.add(new MessageEntry(key, msg, fileName, m.start()));
            }

            for (Matcher m = MOVE_PATTERN.matcher(content);
                 m.find(); ) {
                String msg = m.group(1);
                String var = m.group(2);
                String key = generateKey(fileName, "MOVE_" + var, msg);
                result.add(new MessageEntry(key, msg, fileName, m.start()));
            }

            for (Matcher m = BMS_INITIAL_PATTERN.matcher(content);
                 m.find(); ) {
                String msg = m.group(1);
                String key = generateKey(fileName, "BMS", msg);
                result.add(new MessageEntry(key, msg, fileName, m.start()));
            }
        } catch (IOException ignored) {}
    }

    private String generateKey(String fileName, String prefix, String message) {
        String base = fileName.replaceAll("\\.[^.]+$", "").toLowerCase();
        String shortMsg = message.length() > 40
            ? message.substring(0, 40).replaceAll("[^a-zA-Z0-9]", "_").toUpperCase()
            : message.replaceAll("\\s+", "_").toUpperCase();
        return String.format("%s.%s.%s", base, prefix, shortMsg);
    }

    public record MessageEntry(String key, String originalText, String sourceFile, int charOffset) {}

    public static class ExtractedMessages {
        private final List<MessageEntry> entries = new ArrayList<>();
        private final Map<String, MessageEntry> deduped = new LinkedHashMap<>();

        void add(MessageEntry entry) {
            entries.add(entry);
            deduped.putIfAbsent(entry.originalText(), entry);
        }

        public List<MessageEntry> all() { return List.copyOf(entries); }
        public Collection<MessageEntry> unique() { return deduped.values(); }
    }
}
```

## Message Migration: COBOL → Spring MessageSource

### Properties File Structure

```
src/main/resources/i18n/
├── messages.properties           # Default (fallback) — English
├── messages_en.properties        # English
├── messages_ja.properties        # Japanese
├── messages_de.properties        # German
├── messages_fr.properties        # French
├── messages_es.properties        # Spanish
├── messages_zh_CN.properties     # Simplified Chinese
└── messages_ar.properties        # Arabic (RTL)
```

### Message Key Naming Convention

```
# Format: {module}.{program}.{type}.{identifier}
# Examples:
cust.inqry.err.cust_not_found=Customer not found: {0}
acct.updt.info.update_success=Account updated successfully. New balance: {0,number,#,##0.00}
batch.recon.warn.record_skipped=Record skipped at position {0}: {1}
common.btn.submit=Submit
common.btn.cancel=Cancel
common.val.required_field={0} is required
```

### Example: messages.properties (English — Default)

```properties
# common keys
common.btn.submit=Submit
common.btn.cancel=Cancel
common.btn.reset=Reset
common.val.required_field={0} is a required field
common.val.invalid_format={0} format is invalid
common.err.system_error=A system error has occurred. Please contact support. Ref: {0}
common.lbl.account_number=Account Number
common.lbl.customer_name=Customer Name
common.lbl.balance=Balance

# Customer Inquiry (CUSTINQ.cbl)
cust.inqry.title=Customer Inquiry
cust.inqry.err.cust_not_found=Customer {0} not found in system
cust.inqry.info.record_count={0} record(s) found
cust.inqry.warn.inactive_account=Account {0} is inactive. Contact branch.

# Account Update (ACCTUPD.cbl)
acct.updt.title=Account Update
acct.updt.info.update_success=Account {0} updated. New balance: {1,number,#,##0.00}
acct.updt.err.insufficient_funds=Insufficient funds. Available: {0,number,#,##0.00}
acct.updt.err.limit_exceeded=Transaction exceeds daily limit of {0,number,#,##0.00}
acct.updt.err.account_locked=Account {0} is locked. Reason: {1}

# Batch Processing (BATRECON.cbl)
batch.recon.job.started=Reconciliation batch started at {0}
batch.recon.job.completed=Reconciliation completed. Total: {0}, Matched: {1}, Mismatched: {2}
batch.recon.warn.record_skipped=Record skipped: {0} at line {1}
batch.recon.err.file_not_found=Input file not found: {0}
```

### Example: messages_ja.properties (Japanese)

```properties
# common keys
common.btn.submit=送信
common.btn.cancel=キャンセル
common.btn.reset=リセット
common.val.required_field={0}は必須項目です
common.val.invalid_format={0}の形式が無効です
common.err.system_error=システムエラーが発生しました。サポートにお問い合わせください。Ref: {0}
common.lbl.account_number=口座番号
common.lbl.customer_name=顧客名
common.lbl.balance=残高

# Customer Inquiry
cust.inqry.title=顧客照会
cust.inqry.err.cust_not_found=顧客{0}が見つかりません
cust.inqry.info.record_count={0}件のレコードが見つかりました
cust.inqry.warn.inactive_account=口座{0}は休眠状態です。支店にお問い合わせください。

# Account Update
acct.updt.title=口座更新
acct.updt.info.update_success=口座{0}を更新しました。新残高: {1,number,#,##0.00}
acct.updt.err.insufficient_funds=残高不足です。利用可能額: {0,number,#,##0.00}
acct.updt.err.limit_exceeded=取引が日次限度額{0,number,#,##0.00}を超過しています
acct.updt.err.account_locked=口座{0}はロックされています。理由: {1}

# Batch Processing
batch.recon.job.started=照合バッチが{0}に開始されました
batch.recon.job.completed=照合完了。合計: {0}, 一致: {1}, 不一致: {2}
batch.recon.warn.record_skipped=レコードをスキップしました: {0} (行: {1})
batch.recon.err.file_not_found=入力ファイルが見つかりません: {0}
```

## Spring i18n Configuration

### MessageSource Bean Configuration

```java
@Configuration
public class I18nConfig {

    @Bean
    public MessageSource messageSource() {
        ReloadableResourceBundleMessageSource messageSource =
            new ReloadableResourceBundleMessageSource();
        messageSource.setBasenames(
            "classpath:i18n/messages",
            "classpath:i18n/validation-messages",
            "classpath:i18n/error-messages"
        );
        messageSource.setDefaultEncoding("UTF-8");
        messageSource.setDefaultLocale(Locale.ENGLISH);
        messageSource.setFallbackToSystemLocale(false);
        messageSource.setUseCodeAsDefaultMessage(true);
        messageSource.setCacheSeconds(3600);
        return messageSource;
    }

    @Bean
    public LocaleResolver localeResolver() {
        AcceptHeaderLocaleResolver resolver = new AcceptHeaderLocaleResolver();
        resolver.setDefaultLocale(Locale.ENGLISH);
        resolver.setSupportedLocales(List.of(
            Locale.ENGLISH,
            Locale.JAPANESE,
            Locale.GERMAN,
            Locale.FRENCH,
            new Locale("es"),
            Locale.SIMPLIFIED_CHINESE,
            new Locale("ar")
        ));
        return resolver;
    }

    @Bean
    public LocaleChangeInterceptor localeChangeInterceptor() {
        LocaleChangeInterceptor interceptor = new LocaleChangeInterceptor();
        interceptor.setParamName("lang");
        return interceptor;
    }

    @Bean
    public WebMvcConfigurer localeWebMvcConfigurer(LocaleChangeInterceptor interceptor) {
        return new WebMvcConfigurer() {
            @Override
            public void addInterceptors(InterceptorRegistry registry) {
                registry.addInterceptor(interceptor);
            }
        };
    }
}
```

### MessageSource Usage in Controllers

```java
@RestController
@RequestMapping("/api/v1/customers")
public class CustomerController {

    private final CustomerService customerService;
    private final MessageSource messageSource;

    public CustomerController(CustomerService customerService,
                               MessageSource messageSource) {
        this.customerService = customerService;
        this.messageSource = messageSource;
    }

    @GetMapping("/{customerId}")
    public ResponseEntity<?> getCustomer(@PathVariable String customerId,
                                          Locale locale) {
        return customerService.findCustomer(customerId)
            .map(customer -> ResponseEntity.ok(toResponse(customer, locale)))
            .orElseGet(() -> {
                String message = messageSource.getMessage(
                    "cust.inqry.err.cust_not_found",
                    new Object[]{customerId},
                    locale
                );
                return ResponseEntity.status(HttpStatus.NOT_FOUND)
                    .body(Map.of("code", "CUST_NOT_FOUND", "message", message));
            });
    }

    @PostMapping("/{customerId}/update")
    public ResponseEntity<?> updateCustomer(@PathVariable String customerId,
                                             @Valid @RequestBody UpdateRequest request,
                                             Locale locale) {
        try {
            UpdateResult result = customerService.update(customerId, request);
            String message = messageSource.getMessage(
                "acct.updt.info.update_success",
                new Object[]{customerId, result.newBalance()},
                locale
            );
            return ResponseEntity.ok(Map.of("code", "SUCCESS", "message", message));
        } catch (InsufficientFundsException e) {
            String message = messageSource.getMessage(
                "acct.updt.err.insufficient_funds",
                new Object[]{e.getAvailableBalance()},
                locale
            );
            return ResponseEntity.status(HttpStatus.UNPROCESSABLE_ENTITY)
                .body(Map.of("code", "INSUFFICIENT_FUNDS", "message", message));
        }
    }
}
```

### MessageSource in Services (Non-Web Context)

```java
@Service
public class BatchReconciliationService {

    private final MessageSource messageSource;
    private final Logger log = LoggerFactory.getLogger(getClass());

    public BatchReconciliationService(MessageSource messageSource) {
        this.messageSource = messageSource;
    }

    public ReconciliationReport process(Locale userLocale) {
        String startMsg = messageSource.getMessage(
            "batch.recon.job.started",
            new Object[]{LocalDateTime.now()},
            userLocale
        );
        log.info(startMsg);

        // ... processing ...

        String completeMsg = messageSource.getMessage(
            "batch.recon.job.completed",
            new Object[]{total, matched, mismatched},
            userLocale
        );
        log.info(completeMsg);

        return new ReconciliationReport(completeMsg);
    }
}
```

## Encoding: COBOL Source → UTF-8

### COBOL Source Encoding Detection

```java
public class CobolSourceEncodingDetector {

    private static final byte[] EBCDIC_SIGNATURES = {
        (byte) 0x40, // SPACE in EBCDIC (common filler)
        (byte) 0xF0, // '0' in EBCDIC
        (byte) 0xC1, // 'A' in EBCDIC
        (byte) 0xD1, // 'J' in EBCDIC (PROCEDURE DIVISION)
    };

    public static Charset detectEncoding(byte[] sourceBytes) {
        if (isLikelyEbcdic(sourceBytes)) {
            return detectEbcdicCodePage(sourceBytes);
        }
        if (isUtf8WithBom(sourceBytes)) {
            return StandardCharsets.UTF_8;
        }
        return Charset.forName("IBM-037");
    }

    private static boolean isLikelyEbcdic(byte[] bytes) {
        int ebcdicScore = 0;
        int asciiScore = 0;

        for (int i = 0; i < Math.min(bytes.length, 1000); i++) {
            int b = bytes[i] & 0xFF;
            if (b >= 0x40 && b <= 0xFE) ebcdicScore++;
            if (b >= 0x20 && b <= 0x7E) asciiScore++;
        }
        return ebcdicScore > asciiScore * 1.5;
    }

    private static Charset detectEbcdicCodePage(byte[] bytes) {
        return Charset.forName("IBM-037");
    }

    private static boolean isUtf8WithBom(byte[] bytes) {
        return bytes.length >= 3
            && (bytes[0] & 0xFF) == 0xEF
            && (bytes[1] & 0xFF) == 0xBB
            && (bytes[2] & 0xFF) == 0xBF;
    }
}
```

### Properties File UTF-8 Handling

```
# Enable UTF-8 in application.yml
spring:
  messages:
    encoding: UTF-8
    fallback-to-system-locale: false
    always-use-message-format: true
```

```xml
<!-- Maven resource plugin: ensure properties files are UTF-8 -->
<plugin>
    <groupId>org.apache.maven.plugins</groupId>
    <artifactId>maven-resources-plugin</artifactId>
    <configuration>
        <encoding>UTF-8</encoding>
        <propertiesEncoding>UTF-8</propertiesEncoding>
    </configuration>
</plugin>
```

## RTL Support: Arabic/Hebrew BMS Screen Migration

### RTL Layout Considerations

| Aspect | COBOL BMS (LTR only) | Java Web UI (with RTL) |
|--------|---------------------|----------------------|
| Text direction | Always left-to-right | `dir="rtl"` on `<html>` / `<body>` |
| Field alignment | Fixed column positions | CSS `text-align` / Flexbox RTL |
| Numeric fields | Right-aligned by PIC | Keep right-aligned (numbers) |
| Layout mirroring | N/A | CSS `direction: rtl` flips layout |
| Icons / arrows | Not applicable | Mirror directional icons |

### RTL CSS Configuration

```css
/* rtl.css */
[dir="rtl"] .form-label {
    text-align: right;
}

[dir="rtl"] .input-group > .form-control {
    text-align: right;
}

[dir="rtl"] .action-buttons {
    flex-direction: row-reverse;
}

[dir="rtl"] .table th,
[dir="rtl"] .table td {
    text-align: right;
}

[dir="rtl"] .breadcrumb {
    direction: rtl;
}

[dir="rtl"] .modal-header .close {
    margin-left: 0;
    margin-right: auto;
}
```

## Date / Number Formatting

### COBOL DATE FORMAT → Java DateTimeFormatter

| COBOL DATE FORMAT | Description | Java DateTimeFormatter |
|------------------|-------------|----------------------|
| YYYYMMDD | Basic ISO | `DateTimeFormatter.BASIC_ISO_DATE` |
| YYMMDD | Short year | `DateTimeFormatter.ofPattern("yyMMdd")` |
| DD/MM/YYYY | European | `DateTimeFormatter.ofPattern("dd/MM/yyyy")` |
| MM/DD/YYYY | US | `DateTimeFormatter.ofPattern("MM/dd/yyyy")` |
| YYYY-MM-DD | ISO extended | `DateTimeFormatter.ISO_LOCAL_DATE` |
| YYYYDDD | Julian day | `DateTimeFormatter.ofPattern("yyyyDDD")` |

```java
public class CobolDateFormatter {

    public static String format(String cobolDate, String cobolFormat, Locale locale) {
        DateTimeFormatter inputFmt = switch (cobolFormat) {
            case "YYYYMMDD" -> DateTimeFormatter.BASIC_ISO_DATE;
            case "YYMMDD" -> DateTimeFormatter.ofPattern("yyMMdd");
            case "DD/MM/YYYY" -> DateTimeFormatter.ofPattern("dd/MM/yyyy");
            case "MM/DD/YYYY" -> DateTimeFormatter.ofPattern("MM/dd/yyyy");
            case "YYYYDDD" -> DateTimeFormatter.ofPattern("yyyyDDD");
            default -> DateTimeFormatter.BASIC_ISO_DATE;
        };

        LocalDate date = LocalDate.parse(cobolDate, inputFmt);
        return date.format(DateTimeFormatter.ofLocalizedDate(FormatStyle.MEDIUM)
            .withLocale(locale));
    }
}
```

### COBOL DECIMAL-POINT IS COMMA → Java NumberFormat

| COBOL Setting | Java Equivalent |
|--------------|----------------|
| `DECIMAL-POINT IS COMMA` (European) | `NumberFormat.getInstance(Locale.GERMANY)` |
| Default (US period) | `NumberFormat.getInstance(Locale.US)` |

```java
@Component
public class CobolNumberFormatter {

    public String formatDecimal(BigDecimal value, boolean isCommaDecimal, Locale locale) {
        NumberFormat nf = isCommaDecimal
            ? NumberFormat.getNumberInstance(Locale.GERMANY)
            : NumberFormat.getNumberInstance(locale);
        nf.setMinimumFractionDigits(2);
        nf.setMaximumFractionDigits(2);
        return nf.format(value);
    }
}
```

## EDITED Picture → Java Format Pattern

| COBOL PIC | Description | Java Format |
|-----------|------------|-------------|
| `PIC $,$$$,$$9.99` | US currency with float | `NumberFormat.getCurrencyInstance(Locale.US)` |
| `PIC $$$,$$$,$$9.99` | US currency, float sign | `NumberFormat.getCurrencyInstance(Locale.US)` |
| `PIC ZZZ.ZZ9,99` | European number with comma decimal | `NumberFormat.getNumberInstance(Locale.GERMANY)` |
| `PIC Z,ZZZ,ZZ9.99` | US number | `NumberFormat.getNumberInstance(Locale.US)` |
| `PIC --,--9.99` | With debit sign | Custom pattern `"-##,##0.00"` |
| `PIC ++,++9.99` | With sign | Custom `"+##,##0.00;-##,##0.00"` |
| `PIC **,***9.99` | Check protection (asterisk fill) | `DecimalFormat("**,**0.00")` |
| `PIC Z,ZZ9.99DB` | Debit suffix | Append " DB" for negative |

### Java DecimalFormat Examples

```java
public class EditedPictureConverter {

    public static String formatUsCurrency(BigDecimal value) {
        return NumberFormat.getCurrencyInstance(Locale.US).format(value);
        // PIC $,$$$,$$9.99 → $1,234.56
    }

    public static String formatEuropean(BigDecimal value) {
        return NumberFormat.getNumberInstance(Locale.GERMANY).format(value);
        // PIC ZZZ.ZZ9,99 → 1.234,56
    }

    public static String formatCheckProtection(BigDecimal value) {
        DecimalFormat df = new DecimalFormat("**,**0.00");
        return df.format(value);
        // PIC **,***9.99 → ****12.34
    }

    public static String formatWithSign(BigDecimal value) {
        DecimalFormat df = new DecimalFormat("+##,##0.00;-##,##0.00");
        return df.format(value);
        // PIC ++,++9.99 → +1,234.56 or -1,234.56
    }

    public static String formatDebitCredit(BigDecimal value) {
        if (value.compareTo(BigDecimal.ZERO) < 0) {
            return String.format("%,.2f DB", value.abs());
        }
        return String.format("%,.2f", value);
        // PIC Z,ZZ9.99DB → 1,234.56 DB (for negative)
    }
}
```

## Complete application.yml I18N Configuration

```yaml
spring:
  messages:
    basename: classpath:i18n/messages
    encoding: UTF-8
    fallback-to-system-locale: false
    always-use-message-format: true
    cache-duration: 3600

  web:
    locale: en
    locale-resolver: accept_header

  mvc:
    locale: en
    locale-resolver: accept_header

app:
  i18n:
    supported-locales:
      - en
      - ja
      - de
      - fr
      - es
      - zh_CN
      - ar
    default-locale: en
    date-input-formats:
      YYYYMMDD: yyyyMMdd
      YYMMDD: yyMMdd
      DD_MM_YYYY: dd/MM/yyyy
      MM_DD_YYYY: MM/dd/yyyy
    decimal-point-comma-locales:
      - de
      - fr
      - es
```

## Complete Controller Example with Full i18n

```java
@RestController
@RequestMapping("/api/v1/inquiry")
public class InquiryController {

    private final InquiryService service;
    private final MessageSource messageSource;

    public InquiryController(InquiryService service, MessageSource messageSource) {
        this.service = service;
        this.messageSource = messageSource;
    }

    @GetMapping("/account/{accountId}")
    public ResponseEntity<ApiResponse> inquiry(@PathVariable String accountId,
                                                @RequestHeader(value = "Accept-Language",
                                                    defaultValue = "en") String acceptLang,
                                                Locale locale) {
        try {
            AccountInfo info = service.inquiry(accountId);

            if (info.status().equals("I")) {
                String warning = messageSource.getMessage(
                    "cust.inqry.warn.inactive_account",
                    new Object[]{accountId},
                    locale
                );
                return ResponseEntity.ok(ApiResponse.success(info, warning));
            }

            String message = messageSource.getMessage(
                "cust.inqry.info.record_count",
                new Object[]{1},
                locale
            );
            return ResponseEntity.ok(ApiResponse.success(info, message));

        } catch (NotFoundException e) {
            String msg = messageSource.getMessage(
                "cust.inqry.err.cust_not_found",
                new Object[]{accountId},
                locale
            );
            return ResponseEntity.status(HttpStatus.NOT_FOUND)
                .body(ApiResponse.error("NOT_FOUND", msg));
        }
    }

    public record ApiResponse(String status, String code, String message, Object data) {
        static ApiResponse success(Object data, String message) {
            return new ApiResponse("SUCCESS", "OK", message, data);
        }
        static ApiResponse error(String code, String message) {
            return new ApiResponse("ERROR", code, message, null);
        }
    }
}
```

## Integration Notes

- Referenced by: quality-checklist.md check 31 (BMS Field Completeness), SKILL.md Phase 3 (BMS/Screens analysis), SKILL.md Phase 5 (Logic analysis — DISPLAY extraction), ebcdic-conversion-toolchain.md (encoding source)
- Last reviewed: 2026-05-04
