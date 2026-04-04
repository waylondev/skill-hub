---
name: env-configure-python
description: >-
  Use this skill when the user wants to configure Python environment variables and add Python to system PATH.
version: 1.0.0
displayName: Configure Python Environment Variables
domain: env
action: configure
object: python
tags: [env, python, config, path]
type: SKILL
inputs:
  - name: python_install_path
    type: string
    required: false
    description: Python installation path (auto-detect if not specified)
---
# Configure Python Environment Variables

## Purpose

Configure Python environment variables and add Python executables to system PATH only. Does not handle pip registry configuration.

## Trigger Conditions

Use this Skill when:
- Python is installed and needs to be added to PATH
- User needs python and pip commands accessible from command line
- User wants to set Python as the default python command

## Prerequisites

- Python is installed on the system

## Execution Steps

### Step 1: Verify Prerequisites

Before attempting configuration:
- **Check if Python is installed**: Run `python --version` or `python3 --version`. If not found and `python_install_path` is not provided, inform user: "Python is not installed or not in PATH. Please install Python first or provide the installation path." Stop and do not proceed.
- If prerequisites are not met, inform user and stop.

### Step 2: Detect Python Installation

If `python_install_path` parameter is not provided:
- Locate Python installation using system-specific methods
- Check for both python and python3 executables
- Verify Python is accessible from command line
- If multiple versions exist, identify the preferred version
- If Python is not found, inform user and stop

### Step 3: Check Current Configuration (Idempotency)

Before making changes:
- Check if Python installation directory is already in PATH
- Check if python command is accessible
- Check if pip command is accessible
- If all are correctly configured, inform user: "Python environment variables are already configured correctly. No changes needed." and stop.

### Step 4: Add Python to PATH

Ensure Python executables are accessible:
- Add Python installation directory to PATH
- Include both Python and pip script locations
- Avoid duplicate entries in PATH
- Use appropriate path separator for the platform

### Step 5: Verify Configuration

After configuration:
- Verify Python is accessible: `python --version` or `python3 --version`
- Verify pip is accessible: `pip --version`
- Confirm PATH configuration is correct

### Step 6: Inform User

- Confirm Python environment variables have been configured
- Provide version information for python and pip
- Remind user that terminal restart may be required for changes to take effect
- If pip registry configuration is needed, inform user this is not handled by this skill

## Constraints

- **Single Responsibility**: Only configures Python PATH environment variables. Does not configure pip registry or other pip settings.
- **Idempotent**: Check first, configure only if needed. If already configured correctly, do nothing.
- **Prerequisite Check**: If Python is not installed, inform user and stop.
- User-level environment variables only

## Error Handling

- **Python not installed**: "Python is not installed or not accessible. Please install Python first or provide the installation path."
- **Invalid installation path**: "The provided path does not contain python executable. Please verify the installation path."
- **Already configured**: "Python environment variables are already configured correctly. No action needed."

## Related Skills

- `env-configure-pip` - Configure pip registry (separate responsibility, if needed)
- `env-configure-path` - Generic path configuration alternative
