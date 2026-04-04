---
name: env-configure-java
description: >-
  Use this skill when the user wants to configure Java environment variables, set up JAVA_HOME, or configure JDK environment variables.
version: 1.0.0
displayName: Configure Java Environment Variables
domain: env
action: configure
object: java
tags: [env, java, jdk, config]
type: SKILL
inputs:
  - name: java_home
    type: string
    required: false
    description: Java installation path (auto-detect if not specified)
---
# Configure Java Environment Variables

## Trigger Conditions
Use when Java is installed and environment variables need to be configured.

## Prerequisites
- Java is installed

## Execution Steps
1. Detect Java installation path:
   ```bash
   /usr/libexec/java_home -V 2>/dev/null   # macOS
   ls /usr/lib/jvm/                           # Linux
   ```

2. Configure environment variables:

   **macOS / Linux** (write to ~/.bashrc or ~/.zshrc):
   ```bash
   export JAVA_HOME={{java_home}}
   export PATH=$JAVA_HOME/bin:$PATH
   ```

   **Windows** (system environment variables):
   - JAVA_HOME → {{java_home}}
   - Add %JAVA_HOME%\bin to Path

3. Verify:
   ```bash
   java -version
   echo $JAVA_HOME
   ```

## Constraints
- Only responsible for environment variable configuration, not Java installation
- Idempotent: check if correctly configured if already set, do not rewrite
