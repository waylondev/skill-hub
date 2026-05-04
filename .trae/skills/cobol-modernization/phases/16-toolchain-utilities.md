# Phase 16: Toolchain & Migration Utilities

## Objective

Provide a comprehensive set of migration utility tools that automate repetitive conversion tasks during COBOL-to-Java migration. Each utility addresses a specific gap between COBOL mainframe and Java/PostgreSQL ecosystems, reducing manual effort and eliminating conversion errors.

## Input

- Phase 1: Source Inventory — file lists for batch processing
- Phase 2: VSAM Analysis — file metadata (record formats, keys)
- Phase 4: COPYBOOK Analysis — field definitions and encodings
- Phase 5: Logic Extraction — JCL dependencies and data flows

## Deliverables

- `16-toolchain/flyway-version-tracking.sql` — Flyway migration version tracker template
- `16-toolchain/vsam-to-postgresql-ddl-generator.py` — VSAM→PostgreSQL DDL generator script
- `16-toolchain/comp3-hex-to-bigdecimal.java` — COMP-3 hex dump → BigDecimal converter
- `16-toolchain/ebcdic-to-utf8-converter.java` — EBCDIC→UTF-8 file converter
- `16-toolchain/jcl-dependency-parser.py` — JCL dependency graph parser
- `16-toolchain/copybook-cross-reference-generator.py` — COPYBOOK cross-reference generator
- `16-toolchain/usage-examples.md` — Usage examples for all utilities

## Flyway Version Tracking SQL Template

### Purpose

Track which COBOL programs have been migrated and their corresponding Flyway migration versions. This provides traceability from original COBOL source to the database migration applied.

```sql
-- flyway-version-tracking.sql
-- Maps COBOL VSAM files / programs to Flyway migration versions

CREATE TABLE IF NOT EXISTS migration_tracking (
    tracking_id       BIGSERIAL PRIMARY KEY,
    source_type       VARCHAR(20)  NOT NULL CHECK (source_type IN ('VSAM_FILE', 'COBOL_PROGRAM', 'COPYBOOK')),
    source_name       VARCHAR(100) NOT NULL,
    source_path       VARCHAR(500),
    flyway_version    VARCHAR(20)  NOT NULL,
    migration_script  VARCHAR(200) NOT NULL,
    table_created     VARCHAR(100),
    record_count      BIGINT,
    migration_status  VARCHAR(20)  NOT NULL DEFAULT 'PENDING'
        CHECK (migration_status IN ('PENDING', 'MIGRATED', 'VALIDATED', 'FAILED')),
    migrated_at       TIMESTAMP WITH TIME ZONE,
    validated_at      TIMESTAMP WITH TIME ZONE,
    error_message     TEXT,
    created_at        TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at        TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_mt_source ON migration_tracking(source_type, source_name);
CREATE INDEX idx_mt_status ON migration_tracking(migration_status);

COMMENT ON TABLE migration_tracking IS 'Tracks COBOL-to-PostgreSQL migration progress per source artifact';
```

### Usage Example

```sql
-- Insert tracking record when a Flyway migration is applied
INSERT INTO migration_tracking (source_type, source_name, flyway_version, migration_script, table_created)
VALUES ('VSAM_FILE', 'CARD.FILE', '1.0.0', 'V1__initial_schema.sql', 'cards');

-- Query pending migrations
SELECT source_name, flyway_version FROM migration_tracking WHERE migration_status = 'PENDING';

-- Mark as validated after row count + checksum pass
UPDATE migration_tracking
SET migration_status = 'VALIDATED', validated_at = NOW()
WHERE source_name = 'CARD.FILE';
```

## VSAM → PostgreSQL DDL Generator

### Purpose

Automatically generate PostgreSQL DDL statements from VSAM file metadata extracted in Phase 2. Reads the VSAM analysis document and outputs `CREATE TABLE` with proper column types, indexes, and constraints.

```python
#!/usr/bin/env python3
# vsam-to-postgresql-ddl-generator.py
# Reads Phase 2 VSAM analysis JSON and generates PostgreSQL DDL

import json
import sys
from datetime import datetime

TYPE_MAP = {
    'PIC_X':         'VARCHAR({length})',
    'PIC_9':         'NUMERIC({length})',
    'PIC_9V9':       'NUMERIC({total},{scale})',
    'PIC_S9V9_COMP3': 'NUMERIC({total},{scale})',
    'PIC_S9_COMP':   'BIGINT',
    'PIC_9_COMP':    'NUMERIC({length})',
    'FILLER':        None
}

def generate_ddl(vsam_analysis_path, output_path):
    with open(vsam_analysis_path, 'r') as f:
        metadata = json.load(f)

    ddl_lines = [f"-- Generated: {datetime.now().isoformat()}",
                 f"-- Source: {metadata['vsam_file']}",
                 f"-- Record Length: {metadata['rec_len']}",
                 f"-- Key: {metadata.get('key_field', 'N/A')}",
                 ""]

    table_name = metadata['table_name']
    ddl_lines.append(f"CREATE TABLE IF NOT EXISTS {table_name} (")

    columns = []
    has_id = False
    for field in metadata['fields']:
        col_type = TYPE_MAP.get(field['cobol_type'])
        if col_type is None:
            continue
        col_type = col_type.format(**field)

        nullable = 'NOT NULL' if field.get('is_key') else 'NULL'
        col_def = f"    {field['column_name']} {col_type} {nullable}"
        if field.get('is_key'):
            col_def = f"    {field['column_name']} {col_type} PRIMARY KEY"
            has_id = True
        columns.append(col_def)

    columns.append("    version BIGINT NOT NULL DEFAULT 0")
    columns.append("    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()")
    columns.append("    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()")

    ddl_lines.append(",\n".join(columns))
    ddl_lines.append(");")
    ddl_lines.append("")

    for idx_field in metadata.get('alternate_keys', []):
        idx_name = f"idx_{table_name}_{idx_field['column_name']}"
        ddl_lines.append(f"CREATE INDEX IF NOT EXISTS {idx_name} "
                        f"ON {table_name} ({idx_field['column_name']});")

    ddl_lines.append("")
    seq_name = f"{table_name}_id_seq"
    ddl_lines.append(f"CREATE SEQUENCE IF NOT EXISTS {seq_name} START WITH 1 INCREMENT BY 50;")

    with open(output_path, 'w') as out:
        out.write('\n'.join(ddl_lines))

    print(f"Generated DDL: {output_path}")

if __name__ == '__main__':
    if len(sys.argv) != 3:
        print("Usage: python vsam-to-postgresql-ddl-generator.py <vsam_analysis.json> <output.sql>")
        sys.exit(1)
    generate_ddl(sys.argv[1], sys.argv[2])
```

### Usage Example

```bash
# Generate DDL from Phase 2 VSAM analysis
python vsam-to-postgresql-ddl-generator.py \
  02-vsam-analysis/card-file-metadata.json \
  09-database-migrations/V1__cards.sql

# Process all VSAM files in batch
for f in 02-vsam-analysis/*.json; do
  table=$(basename "$f" .json | sed 's/-metadata//')
  python vsam-to-postgresql-ddl-generator.py "$f" "09-database-migrations/V1__${table}.sql"
done
```

## COMP-3 Hex Dump → BigDecimal Converter

### Purpose

Convert COMP-3 (packed decimal) hex dumps from mainframe data extracts into Java BigDecimal values. COMP-3 stores 2 decimal digits per byte with the last nibble holding the sign (0xC = positive, 0xD = negative).

```java
// comp3-hex-to-bigdecimal.java
// Converts COMP-3 (packed decimal) hex strings to BigDecimal

import java.math.BigDecimal;
import java.math.RoundingMode;

public class Comp3Converter {

    public static BigDecimal hexToBigDecimal(String hex, int scale) {
        if (hex == null || hex.length() % 2 != 0) {
            throw new IllegalArgumentException("Hex string must have even length");
        }

        StringBuilder digits = new StringBuilder();
        boolean negative = false;

        for (int i = 0; i < hex.length() - 1; i++) {
            char c = hex.charAt(i);
            if (!Character.isDigit(c) && (c < 'A' || c > 'F')) {
                throw new IllegalArgumentException("Invalid hex character: " + c);
            }
            digits.append(c);
        }

        char lastNibble = hex.charAt(hex.length() - 1);
        if (lastNibble == 'D' || lastNibble == 'B') {
            negative = true;
        }

        BigDecimal value = new BigDecimal(digits.toString())
            .movePointLeft(scale);

        return negative ? value.negate() : value;
    }

    public static void main(String[] args) {
        // Source: COPYBOOK field PIC S9(15)V99 COMP-3
        // Hex dump example: "12345678901234567C" → 123456789012345.67
        String comp3Hex = "12345678901234567C";
        BigDecimal result = hexToBigDecimal(comp3Hex, 2);
        System.out.println("COMP-3 hex: " + comp3Hex);
        System.out.println("BigDecimal: " + result);

        // Negative example: "0000000123456D" → -1234.56
        String negativeHex = "0000000123456D";
        BigDecimal negResult = hexToBigDecimal(negativeHex, 2);
        System.out.println("COMP-3 hex: " + negativeHex);
        System.out.println("BigDecimal: " + negResult);
    }
}
```

### Usage Example

```bash
# Compile and run
javac Comp3Converter.java
java Comp3Converter
# Output:
# COMP-3 hex: 12345678901234567C
# BigDecimal: 123456789012345.67
# COMP-3 hex: 0000000123456D
# BigDecimal: -1234.56
```

## EBCDIC → UTF-8 File Converter

### Purpose

Convert entire files or byte streams from EBCDIC (IBM-037 / IBM-1047) encoding to UTF-8. Essential for processing mainframe data extracts, COPYBOOK text, and legacy log files.

```java
// ebcdic-to-utf8-converter.java
// Converts EBCDIC-encoded files to UTF-8

import java.io.*;
import java.nio.charset.Charset;
import java.nio.file.*;

public class EbcdicToUtf8Converter {

    private static final Charset EBCDIC_CP037 = Charset.forName("IBM037");
    private static final Charset UTF8 = Charset.forName("UTF-8");

    public static void convert(Path sourcePath, Path targetPath) throws IOException {
        byte[] ebcdicBytes = Files.readAllBytes(sourcePath);
        String utf8String = new String(ebcdicBytes, EBCDIC_CP037);
        Files.writeString(targetPath, utf8String, UTF8);
        System.out.printf("Converted: %s (%d bytes) → %s%n",
            sourcePath, ebcdicBytes.length, targetPath);
    }

    public static void main(String[] args) throws IOException {
        if (args.length < 2) {
            System.out.println("Usage: java EbcdicToUtf8Converter <source> <target>");
            System.out.println("       source: EBCDIC-encoded file or directory");
            System.out.println("       target: UTF-8 output file or directory");
            System.exit(1);
        }

        Path source = Path.of(args[0]);
        Path target = Path.of(args[1]);

        if (Files.isDirectory(source)) {
            Files.createDirectories(target);
            try (var stream = Files.list(source)) {
                stream.forEach(f -> {
                    try {
                        Path out = target.resolve(f.getFileName().toString() + ".utf8");
                        convert(f, out);
                    } catch (IOException e) {
                        System.err.println("Failed: " + f + " - " + e.getMessage());
                    }
                });
            }
        } else {
            convert(source, target);
        }
    }
}
```

### Usage Example

```bash
# Convert single file
javac EbcdicToUtf8Converter.java
java EbcdicToUtf8Converter /mainframe/export/CARD.DAT ./data/card.utf8

# Convert entire directory
java EbcdicToUtf8Converter /mainframe/export/ ./converted/

# Check encoding with file command (Linux)
file -i ./converted/card.dat.utf8
# Output: card.dat.utf8: text/plain; charset=utf-8
```

## JCL Dependency Parser

### Purpose

Parse JCL (Job Control Language) files and extract the job dependency graph: which programs call which, input/output file relationships, and scheduling dependencies. Outputs a JSON dependency graph for visualization and Phase 6 (architecture) planning.

```python
#!/usr/bin/env python3
# jcl-dependency-parser.py
# Parses JCL files and extracts program call graph

import re
import json

def parse_jcl(jcl_path):
    with open(jcl_path, 'r') as f:
        content = f.read()

    job_name_match = re.search(r'^//(\S+)\s+JOB', content, re.MULTILINE)
    job_name = job_name_match.group(1) if job_name_match else 'UNKNOWN'

    steps = []
    step_pattern = re.finditer(r'^//(\S+)\s+EXEC\s+PGM=(\S+)', content, re.MULTILINE)
    for m in step_pattern:
        step_name = m.group(1)
        program = m.group(2)
        steps.append({'step': step_name, 'program': program})

    datasets = []
    dd_pattern = re.finditer(r'^//(\S+)\s+DD\s+DSN=(\S+)', content, re.MULTILINE)
    for m in dd_pattern:
        dd_name = m.group(1)
        dataset = m.group(2)
        datasets.append({'dd': dd_name, 'dataset': dataset})

    schedule = None
    sched_match = re.search(r'//\*\s+SCHEDULE:\s*(\S+)', content)
    if sched_match:
        schedule = sched_match.group(1)

    return {
        'job_name': job_name,
        'source_file': jcl_path,
        'schedule': schedule,
        'steps': steps,
        'datasets': datasets
    }

if __name__ == '__main__':
    import sys
    if len(sys.argv) < 2:
        print("Usage: python jcl-dependency-parser.py <jcl_file_or_directory>")
        sys.exit(1)

    import os
    input_path = sys.argv[1]
    results = []

    if os.path.isdir(input_path):
        for root, _, files in os.walk(input_path):
            for f in files:
                if f.endswith('.jcl') or f.endswith('.JCL'):
                    results.append(parse_jcl(os.path.join(root, f)))
    else:
        results.append(parse_jcl(input_path))

    print(json.dumps(results, indent=2))
```

### Usage Example

```bash
# Parse single JCL file
python jcl-dependency-parser.py ./jcl/CARDDAIL.jcl

# Parse entire JCL directory → JSON dependency graph
python jcl-dependency-parser.py ./jcl/ > jcl-dependency-graph.json

# Visualize with Graphviz (optional)
python jcl2dot.py jcl-dependency-graph.json | dot -Tpng > dependency-graph.png
```

## COPYBOOK Cross-Reference Generator

### Purpose

Scan all COBOL programs and generate a cross-reference showing which COPYBOOK is used by which program, and vice versa. Essential for impact analysis when a COPYBOOK structure changes.

```python
#!/usr/bin/env python3
# copybook-cross-reference-generator.py
# Scans COBOL programs for COPY statements and builds usage matrix

import re
import os
import json

def scan_program(filepath):
    with open(filepath, 'r', encoding='utf-8', errors='replace') as f:
        content = f.read()

    copybooks = []
    for m in re.finditer(r'COPY\s+(\S+)', content, re.IGNORECASE):
        copybook = m.group(1).replace('.', '').replace('"', '').replace("'", "")
        copybooks.append(copybook)

    return copybooks

def build_cross_reference(source_dir):
    program_to_copybooks = {}
    copybook_to_programs = {}

    for root, _, files in os.walk(source_dir):
        for f in files:
            if f.lower().endswith(('.cbl', '.cob', '.cobol')):
                filepath = os.path.join(root, f)
                copybooks = scan_program(filepath)
                if copybooks:
                    program_to_copybooks[f] = copybooks
                    for cb in copybooks:
                        if cb not in copybook_to_programs:
                            copybook_to_programs[cb] = []
                        copybook_to_programs[cb].append(f)

    return {
        'program_to_copybooks': program_to_copybooks,
        'copybook_to_programs': copybook_to_programs,
        'total_programs': len(program_to_copybooks),
        'total_copybooks': len(copybook_to_programs)
    }

if __name__ == '__main__':
    import sys
    source_dir = sys.argv[1] if len(sys.argv) > 1 else '.'
    result = build_cross_reference(source_dir)
    print(json.dumps(result, indent=2))
```

### Usage Example

```bash
# Generate cross-reference for all programs
python copybook-cross-reference-generator.py ./cobol-src/ > copybook-xref.json

# Find all programs using a specific COPYBOOK
python -c "
import json
with open('copybook-xref.json') as f:
    data = json.load(f)
print('\n'.join(data['copybook_to_programs'].get('CARDCOPY', [])))
"
```

## Execution Steps

### Step 1: Install Runtime Dependencies

- Python 3.10+ for script-based utilities
- JDK 21+ for Java-based converters
- PostgreSQL 15+ (local or Docker) for Flyway SQL testing

### Step 2: Generate Flyway Tracking Table

Execute `flyway-version-tracking.sql` against the target database to initialize the migration tracking table.

### Step 3: Run VSAM → DDL Generator

For each VSAM file analyzed in Phase 2, generate corresponding PostgreSQL DDL files.

### Step 4: Run EBCDIC Converter on All Data Files

Convert all EBCDIC-encoded data exports to UTF-8 before loading into PostgreSQL.

### Step 5: Build JCL Dependency Graph

Parse all JCL files to produce the job dependency graph. Feed into Phase 6 (architecture) and Phase 8 (batch configuration).

### Step 6: Build COPYBOOK Cross-Reference

Generate the COPYBOOK usage matrix. Feed into Phase 4 (COPYBOOK analysis) for impact analysis.

### Step 7: Document All Utilities

Write `usage-examples.md` with ready-to-run command examples for each utility.

## Quality Gate

- [ ] Flyway tracking table created and populated with initial migration records
- [ ] All VSAM files have corresponding PostgreSQL DDL generated
- [ ] COMP-3 converter produces correct values for known test vectors
- [ ] EBCDIC converter handles IBM-037, IBM-1047, and EBCDIC code pages for all dialects
- [ ] JCL dependency graph includes all jobs, steps, and dataset relationships
- [ ] COPYBOOK cross-reference covers every program and COPYBOOK
- [ ] All utilities have working usage examples in `usage-examples.md`
- [ ] Each utility includes error handling for malformed input
- [ ] `_state-snapshot.json` updated to `{'phase':16,'status':'complete'}`
