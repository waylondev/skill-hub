---
name: env-configure-java
description: >-
  Configure Java environment variables (JAVA_HOME and PATH).
  Invoke when user needs to set up Java environment for development tools.
  Auto-detects Java installation if path not specified.
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

Use this Skill when:
- Java is installed and environment variables need to be configured
- User needs to set up JAVA_HOME for development tools
- User needs to add Java to PATH for command-line access

## Prerequisites

- Java JDK or JRE is installed on the system

## Execution Steps

### Step 1: Determine Java Installation Path

If `java_home` parameter is not provided:
- Locate Java installation using system-specific methods
- If multiple versions exist, prefer the latest stable version or ask user to specify

### Step 2: Validate Java Installation

Before configuring:
- Verify the detected/provided path exists
- Confirm it contains Java executables
- If validation fails, inform user and request correct path

### Step 3: Set JAVA_HOME Environment Variable

Set JAVA_HOME to point to the Java installation directory:
- Use user-level environment variables (not system-level)
- Check if JAVA_HOME already exists and update only if needed (idempotent)

### Step 4: Add Java to PATH

Add Java bin directory to PATH environment variable:
- Ensure the bin subdirectory is included
- Avoid duplicate entries in PATH

### Step 5: Verify Configuration

After setting environment variables:
- Verify JAVA_HOME is correctly set
- Test that java command is accessible
- Report Java version to confirm successful configuration

### Step 6: Inform User

- Confirm JAVA_HOME has been configured successfully
- Remind user that terminal restart may be required for changes to take effect

## Constraints

- Only responsible for environment variable configuration, not Java installation
- Idempotent: check if JAVA_HOME is already correctly configured
- If multiple Java versions exist, use the one specified or detected as default
- User-level environment variables only (no system-wide changes requiring admin privileges)
- Do not hardcode specific installation paths - detect or use provided parameter

## Error Handling

- **Java not found**: Inform user to install Java first, provide guidance on where to download
- **Invalid path**: If provided or detected java_home doesn't contain Java executables, ask user to verify the installation path
- **Permission denied**: Inform user that admin privileges may be required for system variables, suggest using user-level instead
- **Multiple Java versions**: If multiple versions detected, inform user and ask to specify which one to use

## Related Skills

- `env-configure-maven` - Configure Maven environment (requires Java)
- `env-configure-gradle` - Configure Gradle environment (requires Java)
- `env-configure-path` - Generic path configuration for other tools
