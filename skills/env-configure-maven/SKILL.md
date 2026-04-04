---
name: env-configure-maven
description: >-
  Use this skill when the user wants to configure Maven environment variables (MAVEN_HOME and PATH).
version: 1.0.0
displayName: Configure Maven Environment Variables
domain: env
action: configure
object: maven
tags: [env, maven, java, config]
type: SKILL
inputs:
  - name: maven_home
    type: string
    required: false
    description: Maven installation path (auto-detect if not specified)
---
# Configure Maven Environment Variables

## Purpose

Configure Maven environment variables (MAVEN_HOME and PATH) only. Does not handle settings.xml configuration.

## Trigger Conditions

Use this Skill when:
- Maven is installed and needs MAVEN_HOME environment variable
- User needs to add Maven to system PATH
- User wants to verify Maven environment configuration

## Prerequisites

- Maven is installed on the system
- Java is installed and JAVA_HOME is configured

## Execution Steps

### Step 1: Verify Prerequisites

Before attempting configuration:
- **Check if Maven is installed**: If Maven command is not found and `maven_home` is not provided, inform user: "Maven is not installed or not in PATH. Please install Maven first or provide the installation path."
- **Check if JAVA_HOME is set**: If JAVA_HOME is not configured, inform user: "JAVA_HOME is not configured. Please configure Java first using env-configure-java skill."
- If prerequisites are not met, stop and inform user. Do not attempt configuration.

### Step 2: Detect Maven Installation

If `maven_home` parameter is not provided:
- Detect Maven installation location
- If Maven is not found, inform user and stop

### Step 3: Check Current Configuration (Idempotency)

Before making changes:
- Check if MAVEN_HOME is already set to the correct path
- Check if Maven bin directory is already in PATH
- If both are correctly configured, inform user: "Maven environment variables are already configured correctly. No changes needed." and stop.

### Step 4: Set MAVEN_HOME Environment Variable

Configure the MAVEN_HOME environment variable:
- Point to the Maven installation directory
- Use user-level environment variable (not system-level)

### Step 5: Add Maven to PATH

Ensure Maven's bin directory is in the system PATH:
- Add MAVEN_HOME/bin to PATH
- Avoid duplicate entries

### Step 6: Verify Configuration

After configuration:
- Verify MAVEN_HOME is correctly set
- Verify Maven command is accessible

### Step 7: Inform User

- Confirm Maven environment variables have been configured
- Remind user that terminal restart may be required

## Constraints

- **Single Responsibility**: Only configures environment variables (MAVEN_HOME and PATH). Does not configure settings.xml or repositories.
- **Idempotent**: Check first, configure only if needed. If already configured correctly, do nothing.
- **Prerequisite Check**: If prerequisites are not met, inform user and stop. Do not attempt partial configuration.
- User-level environment variables only

## Error Handling

- **Maven not installed**: "Maven is not installed or not accessible. Please install Maven first or provide the installation path."
- **JAVA_HOME not set**: "JAVA_HOME is not configured. Please use env-configure-java skill first."
- **Already configured**: "Maven environment variables are already configured correctly. No action needed."

## Related Skills

- `env-configure-java` - Configure Java environment (prerequisite)
- `env-configure-path` - Generic path configuration
