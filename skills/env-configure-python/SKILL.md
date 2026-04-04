---
name: env-configure-python
description: >-
  Use this skill when the user wants to configure Python environment variables or set up Python environment.
version: 1.0.0
displayName: Configure Python Environment Variables
domain: env
action: configure
object: python
tags: [env, python, config]
type: SKILL
inputs:
  - name: python_install_path
    type: string
    required: false
    description: Python installation path (auto-detect if not specified)
  - name: pip_registry
    type: string
    required: false
    description: Custom pip registry URL (optional, use default if not specified)
---
# Configure Python Environment Variables

## Trigger Conditions

Use this Skill when:
- Python is installed and needs environment configuration
- User needs to add Python to system PATH
- User wants to configure pip with custom registry
- User needs to set Python as the default python command

## Prerequisites

- Python is installed on the system

## Execution Steps

### Step 1: Detect Python Installation

If `python_install_path` parameter is not provided:
- Locate Python installation using system-specific methods
- Check for both python and python3 executables
- Verify Python is accessible from command line
- If multiple versions exist, identify the preferred version

### Step 2: Add Python to PATH

Ensure Python executables are accessible:
- Add Python installation directory to PATH
- Include both Python and pip script locations
- Avoid duplicate entries in PATH
- Use appropriate path separator for the platform

### Step 3: Configure Python Aliases (Optional)

For systems with multiple Python versions:
- Set up alias for python to point to python3
- Set up alias for pip to point to pip3
- This ensures consistent behavior across sessions

### Step 4: Configure pip Registry (Optional)

If `pip_registry` parameter is provided:
- Set the pip registry URL in pip configuration
- Update or create pip configuration file
- If not provided, use pip's default registry

### Step 5: Verify Installation

After configuration:
- Verify Python is accessible and returns version
- Verify pip is accessible and returns version
- Confirm PATH configuration is correct
- Test that python command works as expected

### Step 6: Inform User

- Confirm Python environment has been configured
- Provide version information for python and pip
- Remind user that terminal restart may be required for changes to take effect
- Explain how to verify the configuration independently

## Constraints

- Only responsible for environment variable configuration, not Python installation
- Idempotent: check if correctly configured, do not rewrite if already set properly
- Use user-level configuration where possible
- Do not modify system Python installation without explicit request
- Respect existing Python virtual environments

## Error Handling

- **Python not found**: Inform user to install Python first or provide the installation path
- **Invalid installation path**: If provided path doesn't contain python executable, ask user to verify
- **Permission denied**: If cannot write to pip configuration, inform user about permission requirements
- **Multiple Python versions**: If multiple versions detected, inform user and clarify which one is being configured

## Related Skills

- `env-configure-path` - Generic path configuration alternative
- `env-configure-nodejs` - Configure Node.js environment (alternative runtime)
