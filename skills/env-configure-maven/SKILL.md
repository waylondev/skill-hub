---
name: env-configure-maven
description: Use this skill when the user wants to configure Maven environment variables, set up MAVEN_HOME and PATH, or add Maven to the system PATH for Java builds. Requires Java to be configured first.
metadata:
  version: 1.0.0
  displayName: Configure Maven Environment Variables
  domain: env
  action: configure
  object: maven
  tags: [env, maven, java, build, config]
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
- Check if Maven is installed
- Check if JAVA_HOME is configured
- If prerequisites are not met, inform user and stop

### Step 2: Detect Maven Installation

If `maven_home` parameter is not provided:
- Detect Maven installation location

### Step 3: Check Current Configuration (Idempotency)

Before making changes:
- Check if MAVEN_HOME is already set to the correct path
- Check if Maven bin directory is already in PATH
- If both are correctly configured, inform user and stop

### Step 4: Set MAVEN_HOME Environment Variable

Configure the MAVEN_HOME environment variable:
- Point to the Maven installation directory
- Use user-level environment variable

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

- **Single Responsibility**: Only configures environment variables (MAVEN_HOME and PATH), not settings.xml or repositories
- **Idempotent**: Check first, configure only if needed
- **Prerequisite Check**: If prerequisites are not met, inform user and stop
- User-level environment variables only

## Error Handling

- **Maven not installed**: Inform user Maven is not installed or not accessible
- **JAVA_HOME not set**: Inform user JAVA_HOME is not configured, need to configure Java first
- **Already configured**: Inform user Maven environment variables are already configured correctly
