---
name: env-configure-python
description: >-
  Use this skill when the user wants to configure Python environment variables,
  add Python to PATH, or set up Python for command-line access.
  Auto-detects Python installation if path not specified.
version: 1.0.0
displayName: Configure Python Environment Variables
domain: env
action: configure
object: python
tags: [env, python, pip, config]
type: SKILL
inputs:
  - name: python_home
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
- Check if Python is installed
- If not installed and path not provided, inform user and stop

### Step 2: Detect Python Installation

If `python_install_path` parameter is not provided:
- Locate Python installation using system-specific methods
- Check for both python and python3 executables
- If multiple versions exist, identify the preferred version

### Step 3: Check Current Configuration (Idempotency)

Before making changes:
- Check if Python installation directory is already in PATH
- Check if python and pip commands are accessible
- If already configured correctly, inform user and stop

### Step 4: Add Python to PATH

Ensure Python executables are accessible:
- Add Python installation directory to PATH
- Include both Python and pip script locations
- Avoid duplicate entries in PATH

### Step 5: Verify Configuration

After configuration:
- Verify Python is accessible
- Verify pip is accessible
- Confirm PATH configuration is correct

### Step 6: Inform User

- Confirm Python environment variables have been configured
- Provide version information for python and pip
- Remind user that terminal restart may be required

## Constraints

- **Single Responsibility**: Only configures Python PATH environment variables, not pip registry or other settings
- **Idempotent**: Check first, configure only if needed
- **Prerequisite Check**: If Python is not installed, inform user and stop
- User-level environment variables only

## Error Handling

- **Python not installed**: Inform user Python is not installed or not accessible
- **Invalid installation path**: Inform user provided path does not contain python executable
- **Already configured**: Inform user Python environment variables are already configured correctly
