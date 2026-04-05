---
name: env-configure-path
description: >-
  Use this skill when the user wants to add a specific path to the PATH environment variable or set environment variables like JAVA_HOME, NODE_HOME, etc.
version: 1.0.0
displayName: Configure Environment Variable Paths
domain: env
action: configure
object: path
tags: [env, path, environment, variable, config]
type: SKILL
inputs:
  - name: path
    type: string
    required: false
    description: Path to add to the PATH environment variable
  - name: variable_name
    type: string
    required: false
    description: Name of the environment variable to set (e.g., JAVA_HOME)
  - name: variable_value
    type: string
    required: false
    description: Value for the environment variable
---
# Configure Environment Variable Paths

## Purpose

This Skill enables adding arbitrary paths to the system PATH environment variable or setting specific environment variables (such as JAVA_HOME, NODE_HOME, etc.).

## Trigger Conditions

Use this Skill when:
- After installing new software, need to add its bin directory to PATH
- Configure environment variables for development tools (JAVA_HOME, PYTHON_HOME, etc.)
- Temporarily add custom tool paths to PATH

## Parameters

| Parameter | Type | Required | Description | Example |
|-----------|------|----------|-------------|---------|
| `path` | string | No | Path to add to the PATH environment variable | Path to software bin directory |
| `variable_name` | string | No | Name of the environment variable to set | JAVA_HOME, NODE_HOME, etc. |
| `variable_value` | string | No | Value for the environment variable | Installation directory path |

## Execution Steps

### Step 1: Validate Input Parameters

- If `path` is provided, verify the path exists on the system
- If `variable_name` and `variable_value` are provided, validate the variable name format (alphanumeric and underscore only)
- If validation fails, inform the user with specific error message

### Step 2: Determine Current Environment

- Detect the operating system and shell environment
- Identify the appropriate configuration method for the platform
- Use user-level environment variables (not system-level)

### Step 3: Set Environment Variable (if requested)

If `variable_name` and `variable_value` are provided:

**Approach:**
- Check if the environment variable already exists
- If exists with different value, update it
- If doesn't exist, create it
- Avoid duplicate entries
- Use platform-appropriate method to set user-level environment variable

### Step 4: Add Path to PATH (if requested)

If `path` is provided:

**Approach:**
- Read current PATH environment variable
- Check if the path already exists in PATH (avoid duplicates)
- If not present, add the path to PATH
- Use platform-appropriate path separator and method

### Step 5: Verify and Inform User

After configuration:
- Confirm the changes have been applied
- Inform user that terminal restart may be required for changes to take effect
- Provide verification commands appropriate for their system

## Constraints

- Only responsible for environment variable configuration, not software installation
- Idempotent: check if correctly configured, do not rewrite if already set properly
- Validate path existence before adding to avoid invalid PATH entries
- Avoid duplicate entries in PATH or duplicate variable definitions
- User-level environment variables only (no system-wide changes requiring admin privileges)
- Do not assume specific directory structures - use provided parameters

## Error Handling

- **Path doesn't exist**: Inform user with clear error message, suggest verifying the installation path
- **Permission denied**: Inform user that admin privileges may be required for system-level variables, suggest using user-level instead
- **Invalid variable name**: Validate environment variable name format before attempting to set
- **Shell config file not found**: Inform user and suggest creating appropriate file for their shell
