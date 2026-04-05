---
name: env-configure-gradle
description: >-
  Configure Gradle environment variables (GRADLE_HOME and PATH).
  Invoke when user needs to set up Gradle for Java project builds.
  Requires Java to be configured first.
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
- Check if JAVA_HOME is configured
- Check if Gradle is installed
- If prerequisites are not met, inform user and stop

### Step 2: Detect Gradle Installation

If `gradle_home` parameter is not provided:
- Detect Gradle installation location

### Step 3: Check Current Configuration (Idempotency)

Before making changes:
- Check if GRADLE_HOME is already set to the correct path
- Check if Gradle bin directory is already in PATH
- If both are correctly configured, inform user and stop

### Step 4: Set GRADLE_HOME Environment Variable

Configure the GRADLE_HOME environment variable:
- Point to the Gradle installation directory
- Use user-level environment variable

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

- **Single Responsibility**: Only configures environment variables (GRADLE_HOME and PATH), not repositories or init scripts
- **Idempotent**: Check first, configure only if needed
- **Prerequisite Check**: If prerequisites are not met, inform user and stop
- User-level environment variables only

## Error Handling

- **JAVA_HOME not set**: Inform user JAVA_HOME is not configured, need to configure Java first
- **Gradle not installed**: Inform user Gradle is not installed or not accessible
- **Already configured**: Inform user Gradle environment variables are already configured correctly

## Related Skills

- `env-configure-java` - Configure Java environment (prerequisite)
- `env-configure-path` - Generic path configuration
