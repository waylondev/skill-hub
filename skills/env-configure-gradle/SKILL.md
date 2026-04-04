---
name: env-configure-gradle
description: >-
  Use this skill when the user wants to configure Gradle environment variables (GRADLE_HOME and PATH).
version: 1.0.0
displayName: Configure Gradle Environment Variables
domain: env
action: configure
object: gradle
tags: [env, gradle, java, build, config]
type: SKILL
inputs:
  - name: gradle_home
    type: string
    required: false
    description: Gradle installation path (auto-detect if not specified)
---
# Configure Gradle Environment Variables

## Purpose

Configure Gradle environment variables (GRADLE_HOME and PATH) only. Does not handle repository or init script configuration.

## Trigger Conditions

Use this Skill when:
- Gradle is installed and needs GRADLE_HOME environment variable
- User needs to add Gradle to system PATH
- User wants to verify Gradle environment configuration

## Prerequisites

- Java is installed and JAVA_HOME is configured
- Gradle is installed on the system

## Execution Steps

### Step 1: Verify Prerequisites

Before attempting configuration:
- **Check if JAVA_HOME is set**: If JAVA_HOME is not configured, inform user: "JAVA_HOME is not configured. Please configure Java first using env-configure-java skill." Stop and do not proceed.
- **Check if Gradle is installed**: If Gradle command is not found and `gradle_home` is not provided, inform user: "Gradle is not installed or not in PATH. Please install Gradle first or provide the installation path." Stop and do not proceed.
- If prerequisites are not met, inform user and stop. Do not attempt configuration.

### Step 2: Detect Gradle Installation

If `gradle_home` parameter is not provided:
- Detect Gradle installation location
- If Gradle is not found, inform user and stop

### Step 3: Check Current Configuration (Idempotency)

Before making changes:
- Check if GRADLE_HOME is already set to the correct path
- Check if Gradle bin directory is already in PATH
- If both are correctly configured, inform user: "Gradle environment variables are already configured correctly. No changes needed." and stop.

### Step 4: Set GRADLE_HOME Environment Variable

Configure the GRADLE_HOME environment variable:
- Point to the Gradle installation directory
- Use user-level environment variable (not system-level)

### Step 5: Add Gradle to PATH

Ensure Gradle executables are accessible:
- Add GRADLE_HOME/bin to PATH
- Avoid duplicate entries

### Step 6: Verify Configuration

After configuration:
- Verify GRADLE_HOME is correctly set
- Verify Gradle command is accessible

### Step 7: Inform User

- Confirm Gradle environment variables have been configured
- Remind user that terminal restart may be required

## Constraints

- **Single Responsibility**: Only configures environment variables (GRADLE_HOME and PATH). Does not configure repositories or init scripts.
- **Idempotent**: Check first, configure only if needed. If already configured correctly, do nothing.
- **Prerequisite Check**: If prerequisites are not met, inform user and stop. Do not attempt partial configuration.
- User-level environment variables only

## Error Handling

- **JAVA_HOME not set**: "JAVA_HOME is not configured. Please use env-configure-java skill first."
- **Gradle not installed**: "Gradle is not installed or not accessible. Please install Gradle first or provide the installation path."
- **Already configured**: "Gradle environment variables are already configured correctly. No action needed."

## Related Skills

- `env-configure-java` - Configure Java environment (prerequisite)
- `env-configure-path` - Generic path configuration
