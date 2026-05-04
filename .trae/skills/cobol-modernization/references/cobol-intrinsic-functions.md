# COBOL Intrinsic Function → Java Mapping Reference

## Overview

This document maps all COBOL intrinsic functions to their Java equivalents. COBOL intrinsic functions are prefixed with `FUNCTION` followed by the function name and arguments enclosed in parentheses.

## Mathematical Functions

### NUMVAL — String to Numeric

| COBOL | Java Equivalent |
|-------|----------------|
| `FUNCTION NUMVAL(arg)` | `new BigDecimal(arg.trim())` |
| `FUNCTION NUMVAL-C(arg)` | `new BigDecimal(arg.trim().replaceAll("[^0-9.\\-]", ""))` |

```cobol
COMPUTE WS-AMOUNT = FUNCTION NUMVAL(WS-STRING)
COMPUTE WS-TOTAL = FUNCTION NUMVAL-C("$1,234.56")
```

```java
BigDecimal wsAmount = new BigDecimal(wsString.trim());
BigDecimal wsTotal = new BigDecimal("$1,234.56".replaceAll("[^0-9.\\-]", ""));
```

### NUMVAL-F — Floating Point String to Numeric

| COBOL | Java Equivalent |
|-------|----------------|
| `FUNCTION NUMVAL-F(arg)` | `Double.parseDouble(arg.trim())` |

### INTEGER — Truncate to Integer

| COBOL | Java Equivalent |
|-------|----------------|
| `FUNCTION INTEGER(arg)` | `(int) Math.floor(Double.parseDouble(arg.trim()))` |

```cobol
COMPUTE WS-INT = FUNCTION INTEGER(123.89)
```

```java
int wsInt = (int) Math.floor(Double.parseDouble("123.89")); // 123
```

### INTEGER-PART — Integer Part

| COBOL | Java Equivalent |
|-------|----------------|
| `FUNCTION INTEGER-PART(arg)` | `new BigDecimal(arg).setScale(0, RoundingMode.DOWN).intValue()` |

### MOD — Modulus

| COBOL | Java Equivalent |
|-------|----------------|
| `FUNCTION MOD(a, b)` | `a % b` (int) / `a.remainder(b)` (BigDecimal) |

```cobol
COMPUTE WS-REM = FUNCTION MOD(17, 5)
```

```java
int wsRem = 17 % 5; // 2
// For BigDecimal:
BigDecimal wsRem = a.remainder(b);
```

### REM — Remainder

| COBOL | Java Equivalent |
|-------|----------------|
| `FUNCTION REM(a, b)` | `a.remainder(b)` (BigDecimal) |

```java
BigDecimal remainder = dividend.remainder(divisor);
```

### RANDOM — Random Number

| COBOL | Java Equivalent |
|-------|----------------|
| `FUNCTION RANDOM` | `Math.random()` |
| `FUNCTION RANDOM(seed)` | `new Random(seed).nextDouble()` |

```cobol
COMPUTE WS-RAND = FUNCTION RANDOM * 100
```

```java
double wsRand = Math.random() * 100;
ThreadLocalRandom.current().nextDouble(0, 100);
```

### MAX — Maximum Value

| COBOL | Java Equivalent |
|-------|----------------|
| `FUNCTION MAX(a, b)` | `Math.max(a, b)` |
| `FUNCTION MAX(a, b, c, ...)` | `IntStream.of(a, b, c).max().orElse(0)` |

```cobol
COMPUTE WS-MAX = FUNCTION MAX(A, B, C)
```

```java
int wsMax = IntStream.of(a, b, c).max().orElse(0);
// Or for BigDecimal:
BigDecimal wsMax = Stream.of(a, b, c).max(BigDecimal::compareTo).orElse(BigDecimal.ZERO);
```

### MIN — Minimum Value

| COBOL | Java Equivalent |
|-------|----------------|
| `FUNCTION MIN(a, b)` | `Math.min(a, b)` |
| `FUNCTION MIN(a, b, c, ...)` | `IntStream.of(a, b, c).min().orElse(0)` |

```cobol
COMPUTE WS-MIN = FUNCTION MIN(A, B, C)
```

```java
int wsMin = IntStream.of(a, b, c).min().orElse(0);
BigDecimal wsMin = Stream.of(a, b, c).min(BigDecimal::compareTo).orElse(BigDecimal.ZERO);
```

### RANGE — Range Check

| COBOL | Java Equivalent |
|-------|----------------|
| `FUNCTION RANGE(arg)` | `Math.abs(max - min)` (manual range) |

```cobol
COMPUTE WS-RANGE = FUNCTION MAX(A, B, C) - FUNCTION MIN(A, B, C)
```

```java
int wsRange = IntStream.of(a, b, c).max().orElse(0) - IntStream.of(a, b, c).min().orElse(0);
```

### SUM — Summation

| COBOL | Java Equivalent |
|-------|----------------|
| `FUNCTION SUM(a, b, c, ...)` | `IntStream.of(a, b, c).sum()` |

```cobol
COMPUTE WS-SUM = FUNCTION SUM(A, B, C, D, E)
```

```java
int wsSum = IntStream.of(a, b, c, d, e).sum();
BigDecimal wsSum = Stream.of(a, b, c, d, e).reduce(BigDecimal.ZERO, BigDecimal::add);
```

### SQRT — Square Root

| COBOL | Java Equivalent |
|-------|----------------|
| `FUNCTION SQRT(arg)` | `Math.sqrt(arg)` |

```cobol
COMPUTE WS-ROOT = FUNCTION SQRT(25)
```

```java
double wsRoot = Math.sqrt(25); // 5.0
BigDecimal wsRoot = BigDecimal.valueOf(Math.sqrt(25.0));
```

### ABS — Absolute Value

| COBOL | Java Equivalent |
|-------|----------------|
| `FUNCTION ABS(arg)` | `Math.abs(arg)` |

### FACTORIAL — Factorial

| COBOL | Java Equivalent |
|-------|----------------|
| `FUNCTION FACTORIAL(n)` | `LongStream.rangeClosed(1, n).reduce(1, (a, b) -> a * b)` |

```java
long factorial = LongStream.rangeClosed(1, n).reduce(1, (a, b) -> a * b);
```

### LOG — Natural Logarithm

| COBOL | Java Equivalent |
|-------|----------------|
| `FUNCTION LOG(arg)` | `Math.log(arg)` |

### LOG10 — Base-10 Logarithm

| COBOL | Java Equivalent |
|-------|----------------|
| `FUNCTION LOG10(arg)` | `Math.log10(arg)` |

### EXP — e^x

| COBOL | Java Equivalent |
|-------|----------------|
| `FUNCTION EXP(arg)` | `Math.exp(arg)` |

### SIN / COS / TAN / ASIN / ACOS / ATAN — Trigonometric

| COBOL | Java Equivalent |
|-------|----------------|
| `FUNCTION SIN(arg)` | `Math.sin(arg)` |
| `FUNCTION COS(arg)` | `Math.cos(arg)` |
| `FUNCTION TAN(arg)` | `Math.tan(arg)` |
| `FUNCTION ASIN(arg)` | `Math.asin(arg)` |
| `FUNCTION ACOS(arg)` | `Math.acos(arg)` |
| `FUNCTION ATAN(arg)` | `Math.atan(arg)` |

### PI — Mathematical Constant

| COBOL | Java Equivalent |
|-------|----------------|
| `FUNCTION PI` | `Math.PI` |

### SIGN — Sign of Number

| COBOL | Java Equivalent |
|-------|----------------|
| `FUNCTION SIGN(arg)` | `Integer.signum(arg)` / `Math.signum(arg)` |

## String Functions

### UPPER-CASE — Convert to Uppercase

| COBOL | Java Equivalent |
|-------|----------------|
| `FUNCTION UPPER-CASE(arg)` | `arg.toUpperCase()` |

```cobol
MOVE FUNCTION UPPER-CASE(WS-NAME) TO WS-UPPER-NAME
```

```java
String wsUpperName = wsName.toUpperCase();
```

### LOWER-CASE — Convert to Lowercase

| COBOL | Java Equivalent |
|-------|----------------|
| `FUNCTION LOWER-CASE(arg)` | `arg.toLowerCase()` |

### TRIM — Remove Leading/Trailing Spaces

| COBOL | Java Equivalent |
|-------|----------------|
| `FUNCTION TRIM(arg)` | `arg.trim()` |
| `FUNCTION TRIM(arg, LEADING)` | `arg.stripLeading()` (Java 11+) |
| `FUNCTION TRIM(arg, TRAILING)` | `arg.stripTrailing()` (Java 11+) |

### REVERSE — Reverse String

| COBOL | Java Equivalent |
|-------|----------------|
| `FUNCTION REVERSE(arg)` | `new StringBuilder(arg).reverse().toString()` |

```cobol
MOVE FUNCTION REVERSE("ABCD") TO WS-REV
```

```java
String wsRev = new StringBuilder("ABCD").reverse().toString(); // "DCBA"
```

### LENGTH — String Length

| COBOL | Java Equivalent |
|-------|----------------|
| `FUNCTION LENGTH(arg)` | `arg.length()` |
| `FUNCTION LENGTH-AN(arg)` | `arg.length()` |

```cobol
COMPUTE WS-LEN = FUNCTION LENGTH(WS-STRING)
```

```java
int wsLen = wsString.length();
```

### ORD — Ordinal Position

| COBOL | Java Equivalent |
|-------|----------------|
| `FUNCTION ORD(arg)` | `(int) arg.charAt(0)` |
| `FUNCTION ORD-MIN(arg)` | `arg.chars().min().orElse(0)` |
| `FUNCTION ORD-MAX(arg)` | `arg.chars().max().orElse(0)` |

```cobol
COMPUTE WS-ORD = FUNCTION ORD("A")
```

```java
int wsOrd = (int) 'A'; // 65
int wsOrdMin = "ABCD".chars().min().orElse(0); // 65
int wsOrdMax = "ABCD".chars().max().orElse(0); // 68
```

### CHAR — Character from Ordinal

| COBOL | Java Equivalent |
|-------|----------------|
| `FUNCTION CHAR(n)` | `String.valueOf((char) n)` |

```java
String ch = String.valueOf((char) 65); // "A"
```

### NUMVAL — String to Number (String Context)

```cobol
MOVE FUNCTION NUMVAL(WS-NUM-STRING) TO WS-NUMBER
```

```java
BigDecimal wsNumber = new BigDecimal(wsNumString.trim());
```

### SUBSTITUTE — Substring Replacement

| COBOL | Java Equivalent |
|-------|----------------|
| `FUNCTION SUBSTITUTE(str, from, pos, len)` | `str.substring(0, pos-1) + from + str.substring(pos-1+len)` |

```java
String result = str.substring(0, pos - 1) + from + str.substring(pos - 1 + len);
```

### SUBSTITUTE-CASE — Case-Insensitive Substring Replace

| COBOL | Java Equivalent |
|-------|----------------|
| `FUNCTION SUBSTITUTE-CASE(str, from, pos, len)` | Replace with `(?i)` regex flag |

```java
String result = str.replaceAll("(?i)" + Pattern.quote(target), replacement);
```

### CONCAT — String Concatenation

| COBOL | Java Equivalent |
|-------|----------------|
| `FUNCTION CONCAT(a, b)` | `a + b` / `a.concat(b)` |

### STORED-CHAR-LENGTH — Stored Character Length

| COBOL | Java Equivalent |
|-------|----------------|
| `FUNCTION STORED-CHAR-LENGTH(arg)` | `arg.getBytes(StandardCharsets.UTF_8).length` |

### DISPLAY-OF — Convert to Display

| COBOL | Java Equivalent |
|-------|----------------|
| `FUNCTION DISPLAY-OF(arg)` | `new String(arg, Charset.forName("IBM-037"))` (EBCDIC→ASCII) |

### NATIONAL-OF — Convert to National

| COBOL | Java Equivalent |
|-------|----------------|
| `FUNCTION NATIONAL-OF(arg)` | `new String(arg.getBytes(StandardCharsets.ISO_8859_1), StandardCharsets.UTF_16)` |

### HEX-OF — Convert to Hexadecimal

| COBOL | Java Equivalent |
|-------|----------------|
| `FUNCTION HEX-OF(arg)` | `DatatypeConverter.printHexBinary(bytes)` / `String.format("%02X", ...)` |

## Date / Time Functions

### CURRENT-DATE — Current Date & Time

| COBOL | Java Equivalent |
|-------|----------------|
| `FUNCTION CURRENT-DATE` | `LocalDateTime.now()` |
| `FUNCTION CURRENT-DATE(1)` | `LocalDate.now().format(DateTimeFormatter.BASIC_ISO_DATE)` |

```cobol
MOVE FUNCTION CURRENT-DATE TO WS-CURRENT-DATE
```

```java
String wsCurrentDate = LocalDateTime.now()
    .format(DateTimeFormatter.ofPattern("yyyyMMddHHmmssSSS"));
// Or fields:
LocalDateTime now = LocalDateTime.now();
int year = now.getYear();
int month = now.getMonthValue();
int day = now.getDayOfMonth();
```

### DATE-OF-INTEGER — Integer to Date

| COBOL | Java Equivalent |
|-------|----------------|
| `FUNCTION DATE-OF-INTEGER(n)` | `LocalDate.ofEpochDay(n - DATE_EPOCH_OFFSET)` |

```cobol
MOVE FUNCTION DATE-OF-INTEGER(20000) TO WS-DATE
```

```java
LocalDate epoch = LocalDate.of(1601, 1, 1);
LocalDate wsDate = epoch.plusDays(20000 - 1);
```

### INTEGER-OF-DATE — Date to Integer

| COBOL | Java Equivalent |
|-------|----------------|
| `FUNCTION INTEGER-OF-DATE(date)` | `ChronoUnit.DAYS.between(epoch, date) + 1` |

```java
long days = ChronoUnit.DAYS.between(
    LocalDate.of(1601, 1, 1),
    LocalDate.parse("20241015", DateTimeFormatter.BASIC_ISO_DATE)
) + 1;
```

### DAY-OF-INTEGER — Integer to Day

| COBOL | Java Equivalent |
|-------|----------------|
| `FUNCTION DAY-OF-INTEGER(n)` | `LocalDate.ofYearDay(baseYear, n)` + format |

```java
LocalDate date = LocalDate.ofYearDay(baseYear, n);
String result = date.format(DateTimeFormatter.ofPattern("yyyyDDD"));
```

### INTEGER-OF-DAY — Day to Integer

| COBOL | Java Equivalent |
|-------|----------------|
| `FUNCTION INTEGER-OF-DAY(arg)` | `date.getDayOfYear()` |

### YEAR-TO-YYYY — Year Window

| COBOL | Java Equivalent |
|-------|----------------|
| `FUNCTION YEAR-TO-YYYY(yr, cutoff)` | `yr + (yr < cutoff ? 2000 : 1900)` |

```java
int fullYear = yr + (yr < cutoff ? 2000 : 1900);
```

### DATEVAL — Date Validation

| COBOL | Java Equivalent |
|-------|----------------|
| `FUNCTION DATEVAL(arg)` | Try `LocalDate.parse()` catch `DateTimeParseException` → 0 |

```java
public static int dateval(String dateStr, String pattern) {
    try {
        LocalDate.parse(dateStr, DateTimeFormatter.ofPattern(pattern));
        return 1;
    } catch (DateTimeParseException e) {
        return 0;
    }
}
```

### YEAR — Extract Year

| COBOL | Java Equivalent |
|-------|----------------|
| `FUNCTION YEAR(n)` | `LocalDate.ofEpochDay(n).getYear()` |

### MONTH — Extract Month

| COBOL | Java Equivalent |
|-------|----------------|
| `FUNCTION MONTH(n)` | `LocalDate.ofEpochDay(n).getMonthValue()` |

### DAY — Extract Day

| COBOL | Java Equivalent |
|-------|----------------|
| `FUNCTION DAY(n)` | `LocalDate.ofEpochDay(n).getDayOfMonth()` |

### WEEKDAY — Day of Week

| COBOL | Java Equivalent |
|-------|----------------|
| `FUNCTION WEEKDAY(n)` | `LocalDate.ofEpochDay(n).getDayOfWeek().getValue()` |

### INTEGER — Integer Part of Date

| COBOL | Java Equivalent |
|-------|----------------|
| `FUNCTION INTEGER(dateField)` | `.getYear()` / `.getMonthValue()` / `.getDayOfMonth()` on LocalDate |

### FORMATTED-CURRENT-DATE — Formatted Current Date

| COBOL | Java Equivalent |
|-------|----------------|
| `FUNCTION FORMATTED-CURRENT-DATE(fmt)` | `LocalDate.now().format(DateTimeFormatter.ofPattern(fmt))` |

### FORMATTED-DATE — Format Date

| COBOL | Java Equivalent |
|-------|----------------|
| `FUNCTION FORMATTED-DATE(fmt, n)` | `LocalDate.ofEpochDay(n).format(DateTimeFormatter.ofPattern(fmt))` |

## Statistical Functions

### STANDARD-DEVIATION — Standard Deviation

| COBOL | Java Equivalent |
|-------|----------------|
| `FUNCTION STANDARD-DEVIATION(args)` | `DescriptiveStatistics` (Apache Commons Math) / custom `stdDev()` |

```java
import org.apache.commons.math3.stat.descriptive.DescriptiveStatistics;

DescriptiveStatistics stats = new DescriptiveStatistics();
for (double val : values) stats.addValue(val);
double stdDev = stats.getStandardDeviation();

// Or manual:
double mean = Arrays.stream(values).average().orElse(0);
double variance = Arrays.stream(values)
    .map(v -> Math.pow(v - mean, 2))
    .average().orElse(0);
double stdDev = Math.sqrt(variance);
```

### VARIANCE — Variance

| COBOL | Java Equivalent |
|-------|----------------|
| `FUNCTION VARIANCE(args)` | `stats.getVariance()` (Apache Commons Math) |

### MEDIAN — Median

| COBOL | Java Equivalent |
|-------|----------------|
| `FUNCTION MEDIAN(args)` | `stats.getPercentile(50)` (Apache Commons Math) |

```java
double[] sorted = Arrays.copyOf(values, values.length);
Arrays.sort(sorted);
double median;
if (sorted.length % 2 == 0) {
    median = (sorted[sorted.length / 2 - 1] + sorted[sorted.length / 2]) / 2.0;
} else {
    median = sorted[sorted.length / 2];
}
```

### MEAN — Arithmetic Mean

| COBOL | Java Equivalent |
|-------|----------------|
| `FUNCTION MEAN(args)` | `Arrays.stream(values).average().orElse(0)` |

### RANGE — Statistical Range

| COBOL | Java Equivalent |
|-------|----------------|
| `FUNCTION RANGE(args)` | `max - min` from stream |

### MIDRANGE — Midrange

| COBOL | Java Equivalent |
|-------|----------------|
| `FUNCTION MIDRANGE(args)` | `(max + min) / 2.0` |

## Financial Functions

### ANNUITY — Annuity Payment

| COBOL | Java Equivalent |
|-------|----------------|
| `FUNCTION ANNUITY(rate, nper)` | Custom financial calculation |

```cobol
COMPUTE WS-PMT = FUNCTION ANNUITY(WS-RATE, WS-NPER)
```

```java
public static BigDecimal annuity(BigDecimal rate, int nper) {
    if (rate.compareTo(BigDecimal.ZERO) == 0) {
        return BigDecimal.ONE.divide(BigDecimal.valueOf(nper), 10, RoundingMode.HALF_UP);
    }
    BigDecimal onePlusRate = BigDecimal.ONE.add(rate);
    BigDecimal factor = BigDecimal.ONE.divide(onePlusRate.pow(nper), 10, RoundingMode.HALF_UP);
    return rate.divide(BigDecimal.ONE.subtract(factor), 10, RoundingMode.HALF_UP);
}
```

### PRESENT-VALUE — Present Value

| COBOL | Java Equivalent |
|-------|----------------|
| `FUNCTION PRESENT-VALUE(rate, values...)` | Discount each cash flow manually |

```java
public static BigDecimal presentValue(BigDecimal rate, BigDecimal... cashFlows) {
    BigDecimal pv = BigDecimal.ZERO;
    for (int i = 0; i < cashFlows.length; i++) {
        BigDecimal discountFactor = BigDecimal.ONE.add(rate).pow(i + 1);
        pv = pv.add(cashFlows[i].divide(discountFactor, 10, RoundingMode.HALF_UP));
    }
    return pv;
}
```

### FUTURE-VALUE — Future Value

```java
public static BigDecimal futureValue(BigDecimal rate, int nper, BigDecimal pmt) {
    BigDecimal onePlusRate = BigDecimal.ONE.add(rate);
    return pmt.multiply(
        onePlusRate.pow(nper).subtract(BigDecimal.ONE)
    ).divide(rate, 10, RoundingMode.HALF_UP);
}
```

## Bit / Boolean Functions

### BOOLEAN-OF-INTEGER — Integer to Boolean

| COBOL | Java Equivalent |
|-------|----------------|
| `FUNCTION BOOLEAN-OF-INTEGER(n, pos)` | `((n >> (pos - 1)) & 1) == 1` |

### HEX-TO-CHAR — Hex to Character

| COBOL | Java Equivalent |
|-------|----------------|
| `FUNCTION HEX-TO-CHAR(hex)` | `(char) Integer.parseInt(hex, 16)` |

## Migration Strategy

### Utility Class Template

```java
package com.example.migration.util;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.time.temporal.ChronoUnit;
import java.util.Arrays;
import java.util.Random;
import java.util.stream.IntStream;
import java.util.stream.Stream;

public final class IntrinsicFunctionUtil {

    private IntrinsicFunctionUtil() {}

    public static final LocalDate COBOL_EPOCH = LocalDate.of(1601, 1, 1);

    // Mathematical
    public static BigDecimal numval(String arg) {
        return new BigDecimal(arg.trim());
    }

    public static BigDecimal numvalC(String arg) {
        return new BigDecimal(arg.trim().replaceAll("[^0-9.\\-]", ""));
    }

    public static int integerPart(BigDecimal arg) {
        return arg.setScale(0, RoundingMode.DOWN).intValue();
    }

    public static BigDecimal max(BigDecimal... values) {
        return Stream.of(values).max(BigDecimal::compareTo).orElse(BigDecimal.ZERO);
    }

    public static BigDecimal min(BigDecimal... values) {
        return Stream.of(values).min(BigDecimal::compareTo).orElse(BigDecimal.ZERO);
    }

    public static BigDecimal sum(BigDecimal... values) {
        return Stream.of(values).reduce(BigDecimal.ZERO, BigDecimal::add);
    }

    public static int range(int... values) {
        IntStream stream = Arrays.stream(values);
        return stream.max().orElse(0) - stream.min().orElse(0);
    }

    public static BigDecimal factorial(int n) {
        return BigDecimal.valueOf(
            java.util.stream.LongStream.rangeClosed(1, n).reduce(1, (a, b) -> a * b)
        );
    }

    public static BigDecimal random(int max) {
        return BigDecimal.valueOf(Math.random() * max);
    }

    public static BigDecimal sqrt(BigDecimal arg) {
        return BigDecimal.valueOf(Math.sqrt(arg.doubleValue()));
    }

    // String
    public static String reverse(String arg) {
        return arg != null ? new StringBuilder(arg).reverse().toString() : "";
    }

    public static int ordMin(String arg) {
        return arg.chars().min().orElse(0);
    }

    public static int ordMax(String arg) {
        return arg.chars().max().orElse(0);
    }

    public static String substitute(String str, String replacement, int pos, int len) {
        int idx = pos - 1;
        return str.substring(0, idx) + replacement + str.substring(idx + len);
    }

    // Date
    public static int integerOfDate(String yyyymmdd) {
        LocalDate date = LocalDate.parse(yyyymmdd, DateTimeFormatter.BASIC_ISO_DATE);
        return (int) ChronoUnit.DAYS.between(COBOL_EPOCH, date) + 1;
    }

    public static String dateOfInteger(int days) {
        return COBOL_EPOCH.plusDays(days - 1)
            .format(DateTimeFormatter.BASIC_ISO_DATE);
    }

    public static int integerOfDay(String yyyyddd) {
        int year = Integer.parseInt(yyyyddd.substring(0, 4));
        int dayOfYear = Integer.parseInt(yyyyddd.substring(4));
        LocalDate date = LocalDate.ofYearDay(year, dayOfYear);
        return (int) ChronoUnit.DAYS.between(COBOL_EPOCH, date) + 1;
    }

    public static String dayOfInteger(int days) {
        LocalDate date = COBOL_EPOCH.plusDays(days - 1);
        return String.format("%04d%03d", date.getYear(), date.getDayOfYear());
    }

    public static int yearToYyyy(int yr, int cutoff) {
        return yr + (yr < cutoff ? 2000 : 1900);
    }

    public static int weekDay(int days) {
        return COBOL_EPOCH.plusDays(days - 1).getDayOfWeek().getValue();
    }

    // Statistical
    public static double mean(double... values) {
        return Arrays.stream(values).average().orElse(0);
    }

    public static double median(double... values) {
        double[] sorted = Arrays.copyOf(values, values.length);
        Arrays.sort(sorted);
        int len = sorted.length;
        return (len % 2 == 0)
            ? (sorted[len / 2 - 1] + sorted[len / 2]) / 2.0
            : sorted[len / 2];
    }

    public static double variance(double... values) {
        double mean = mean(values);
        return Arrays.stream(values)
            .map(v -> Math.pow(v - mean, 2))
            .average().orElse(0);
    }

    public static double standardDeviation(double... values) {
        return Math.sqrt(variance(values));
    }

    // Financial
    public static BigDecimal annuity(BigDecimal rate, int nper) {
        if (rate.compareTo(BigDecimal.ZERO) == 0) {
            return BigDecimal.ONE.divide(BigDecimal.valueOf(nper), 10, RoundingMode.HALF_UP);
        }
        BigDecimal onePlusRate = BigDecimal.ONE.add(rate);
        BigDecimal factor = BigDecimal.ONE.divide(onePlusRate.pow(nper), 10, RoundingMode.HALF_UP);
        return rate.divide(BigDecimal.ONE.subtract(factor), 10, RoundingMode.HALF_UP);
    }

    public static BigDecimal presentValue(BigDecimal rate, BigDecimal... cashFlows) {
        BigDecimal pv = BigDecimal.ZERO;
        for (int i = 0; i < cashFlows.length; i++) {
            BigDecimal discountFactor = BigDecimal.ONE.add(rate).pow(i + 1);
            pv = pv.add(cashFlows[i].divide(discountFactor, 10, RoundingMode.HALF_UP));
        }
        return pv;
    }
}
```

### Usage in Migrated Services

```java
@Service
public class InterestCalculationService {

    public BigDecimal calculateInterest(BigDecimal principal, BigDecimal rate, int nper) {
        BigDecimal payment = IntrinsicFunctionUtil.annuity(rate, nper);
        return payment.multiply(BigDecimal.valueOf(nper)).subtract(principal)
            .setScale(2, RoundingMode.HALF_UP);
    }
}
```

## Quick Lookup Table (All 56 Functions)

| # | COBOL Function | Category | Java Equivalent |
|---|---------------|----------|----------------|
| 1 | `FUNCTION NUMVAL(arg)` | Math | `new BigDecimal(arg.trim())` |
| 2 | `FUNCTION NUMVAL-C(arg)` | Math | `new BigDecimal(clean(arg))` |
| 3 | `FUNCTION NUMVAL-F(arg)` | Math | `Double.parseDouble(arg.trim())` |
| 4 | `FUNCTION INTEGER(arg)` | Math | `(int) Math.floor(Double.parseDouble(arg))` |
| 5 | `FUNCTION INTEGER-PART(arg)` | Math | `bd.setScale(0, DOWN).intValue()` |
| 6 | `FUNCTION MOD(a,b)` | Math | `a % b` / `a.remainder(b)` |
| 7 | `FUNCTION REM(a,b)` | Math | `a.remainder(b)` |
| 8 | `FUNCTION RANDOM` | Math | `Math.random()` |
| 9 | `FUNCTION MAX(a,b,...)` | Math | `Stream.max(BigDecimal::compareTo)` |
| 10 | `FUNCTION MIN(a,b,...)` | Math | `Stream.min(BigDecimal::compareTo)` |
| 11 | `FUNCTION SUM(args)` | Math | `Stream.reduce(ZERO, add)` |
| 12 | `FUNCTION SQRT(arg)` | Math | `Math.sqrt(arg)` |
| 13 | `FUNCTION ABS(arg)` | Math | `Math.abs(arg)` |
| 14 | `FUNCTION FACTORIAL(n)` | Math | `LongStream.rangeClosed(1,n).reduce(1,...)` |
| 15 | `FUNCTION LOG(arg)` | Math | `Math.log(arg)` |
| 16 | `FUNCTION LOG10(arg)` | Math | `Math.log10(arg)` |
| 17 | `FUNCTION EXP(arg)` | Math | `Math.exp(arg)` |
| 18 | `FUNCTION SIN(arg)` | Math | `Math.sin(arg)` |
| 19 | `FUNCTION COS(arg)` | Math | `Math.cos(arg)` |
| 20 | `FUNCTION TAN(arg)` | Math | `Math.tan(arg)` |
| 21 | `FUNCTION ASIN(arg)` | Math | `Math.asin(arg)` |
| 22 | `FUNCTION ACOS(arg)` | Math | `Math.acos(arg)` |
| 23 | `FUNCTION ATAN(arg)` | Math | `Math.atan(arg)` |
| 24 | `FUNCTION PI` | Math | `Math.PI` |
| 25 | `FUNCTION SIGN(arg)` | Math | `Math.signum(arg)` |
| 26 | `FUNCTION UPPER-CASE(arg)` | String | `arg.toUpperCase()` |
| 27 | `FUNCTION LOWER-CASE(arg)` | String | `arg.toLowerCase()` |
| 28 | `FUNCTION TRIM(arg)` | String | `arg.trim()` |
| 29 | `FUNCTION REVERSE(arg)` | String | `new StringBuilder(arg).reverse().toString()` |
| 30 | `FUNCTION LENGTH(arg)` | String | `arg.length()` |
| 31 | `FUNCTION LENGTH-AN(arg)` | String | `arg.length()` |
| 32 | `FUNCTION ORD(arg)` | String | `(int) arg.charAt(0)` |
| 33 | `FUNCTION ORD-MIN(arg)` | String | `arg.chars().min().orElse(0)` |
| 34 | `FUNCTION ORD-MAX(arg)` | String | `arg.chars().max().orElse(0)` |
| 35 | `FUNCTION CHAR(n)` | String | `String.valueOf((char) n)` |
| 36 | `FUNCTION SUBSTITUTE(...)` | String | `String.substitute pattern (varargs)` |
| 37 | `FUNCTION SUBSTITUTE-CASE(...)` | String | Regex `(?i)` replace |
| 38 | `FUNCTION CONCAT(a,b)` | String | `a + b` / `a.concat(b)` |
| 39 | `FUNCTION STORED-CHAR-LENGTH(a)` | String | `string.getBytes(UTF_8).length` |
| 40 | `FUNCTION DISPLAY-OF(a)` | String | EBCDIC→ASCII conversion |
| 41 | `FUNCTION NATIONAL-OF(a)` | String | ISO-8859-1→UTF-16 conversion |
| 42 | `FUNCTION HEX-OF(arg)` | String | `HexBin.encode(bytes)` |
| 43 | `FUNCTION CURRENT-DATE` | Date | `LocalDateTime.now()` |
| 44 | `FUNCTION DATE-OF-INTEGER(n)` | Date | `COBOL_EPOCH.plusDays(n - 1)` |
| 45 | `FUNCTION INTEGER-OF-DATE(d)` | Date | `ChronoUnit.DAYS.between(epoch, d) + 1` |
| 46 | `FUNCTION DAY-OF-INTEGER(n)` | Date | `date.format(yyyyDDD)` |
| 47 | `FUNCTION INTEGER-OF-DAY(d)` | Date | Epoch days computation |
| 48 | `FUNCTION YEAR-TO-YYYY(yr,cutoff)` | Date | `yr + (yr < cutoff ? 2000 : 1900)` |
| 49 | `FUNCTION DATEVAL(arg)` | Date | Try-parse + validation |
| 50 | `FUNCTION FORMATTED-CURRENT-DATE(fmt)` | Date | `LocalDate.now().format(pattern)` |
| 51 | `FUNCTION FORMATTED-DATE(fmt, n)` | Date | `COBOL_EPOCH.plusDays(n - 1).format(pattern)` |
| 52 | `FUNCTION STANDARD-DEVIATION(...)` | Stats | Apache Commons Math `getStandardDeviation()` |
| 53 | `FUNCTION VARIANCE(...)` | Stats | Apache Commons Math `getVariance()` |
| 54 | `FUNCTION MEDIAN(...)` | Stats | Sorted array median calculation |
| 55 | `FUNCTION MEAN(...)` | Stats | `Arrays.stream(values).average().orElse(0)` |
| 56 | `FUNCTION ANNUITY(rate, nper)` | Financial | Custom annuity payment formula |
| 57 | `FUNCTION PRESENT-VALUE(rate, ...)` | Financial | Discounted cash flow computation |

## Special Considerations

### Precision Handling

COBOL COMPUTE defaults to maximum precision. Java BigDecimal arithmetic must explicitly specify scale and RoundingMode:

```java
BigDecimal result = a.multiply(b).setScale(2, RoundingMode.HALF_UP);
```

### EBCDIC Source Considerations

When migrating COBOL programs with EBCDIC source, `FUNCTION HEX-OF` results may differ between EBCDIC and ASCII environments. Always test hex output against the original runtime environment.

### PERFORM VARYING → Intrinsic Function Conversion

Patterns often using PERFORM loops for aggregation should be replaced with Stream operations:

```cobol
PERFORM VARYING I FROM 1 BY 1 UNTIL I > 100
    COMPUTE WS-TOTAL = WS-TOTAL + WS-ARRAY(I)
END-PERFORM
```

```java
BigDecimal wsTotal = Arrays.stream(wsArray)
    .reduce(BigDecimal.ZERO, BigDecimal::add);
```

## Integration Notes

- Referenced by: quality-checklist.md checks 1-5 (logic coverage), cobol-to-java-mappings.md (COMPUTE translation), SKILL.md Phase 5 (Logic analysis)
- Last reviewed: 2026-05-04
