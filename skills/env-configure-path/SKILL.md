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
| `path` | string | No | Path to add to the PATH environment variable | `C:\Program Files\Java\jdk-21\bin` |
| `variable_name` | string | No | Name of the environment variable to set (e.g., JAVA_HOME) | `JAVA_HOME` |
| `variable_value` | string | No | Value for the environment variable | `C:\Program Files\Java\jdk-21` |

## Execution Steps

### Windows System

1. **Validate the provided path** (if path parameter is given):
   - Check if the path exists using `Test-Path`
   - If path doesn't exist, inform the user and stop

2. **Set environment variable** (if variable_name and variable_value are given):
   ```powershell
   # Set user-level environment variable
   [Environment]::SetEnvironmentVariable("{{variable_name}}", "{{variable_value}}", "User")
   ```

3. **Add path to PATH** (if path parameter is given):
   ```powershell
   # Get current PATH
   $currentPath = [Environment]::GetEnvironmentVariable("PATH", "User")
   
   # Check if path already exists in PATH
   if ($currentPath -notlike "*{{path}}*") {
       # Append new path
       $newPath = $currentPath + ";{{path}}"
       [Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
   }
   ```

4. **Inform the user**:
   - Environment variable has been set/updated
   - May need to restart terminal or system for changes to take effect

### macOS/Linux System

1. **Validate the provided path** (if path parameter is given):
   - Check if the path exists using `test -d`
   - If path doesn't exist, inform the user and stop

2. **Set environment variable** (if variable_name and variable_value are given):
   - Determine shell config file (`~/.bashrc`, `~/.zshrc`, etc.)
   - Check if variable already exists
   - If exists, update it; if not, append:
   ```bash
   export {{variable_name}}="{{variable_value}}"
   ```

3. **Add path to PATH** (if path parameter is given):
   - Check if path already in PATH
   - If not, append to shell config file:
   ```bash
   export PATH="{{path}}:$PATH"
   ```

4. **Inform the user**:
   - Environment variable has been set/updated
   - May need to run `source ~/.bashrc` or restart terminal

## Constraints

- Only responsible for environment variable configuration, not software installation
- Idempotent: check if correctly configured, do not rewrite if already set
- Validate path existence before adding
- Avoid duplicate entries in PATH
- User-level environment variables only (no system-wide changes)

## Error Handling

- **Path doesn't exist**: Inform user with clear error message, suggest checking the path
- **Permission denied**: Inform user that admin privileges may be required for system variables
- **Invalid variable name**: Validate environment variable name format (alphanumeric and underscore only)

## Related Skills

- `env-configure-java` - Specifically for Java environment configuration
- `env-configure-nodejs` - Specifically for Node.js environment configuration
- `env-configure-python` - Specifically for Python environment configuration
