---
name: env-configure-python
description: >-
  Use this skill when the user wants to configure Python environment variables or set up Python environment variables.
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
---
# Configure Python Environment Variables

## Trigger Conditions
Use when Python is installed and environment variables need to be configured.

## Prerequisites
- Python is installed

## Execution Steps
1. Detect Python installation path:
   ```bash
   which python3  # macOS / Linux
   where python   # Windows
   ```

2. Configure environment variables:

   **macOS / Linux** (write to ~/.bashrc or ~/.zshrc):
   ```bash
   export PATH={{python_install_path}}:$PATH
   export PATH={{python_install_path}}/Scripts:$PATH
   alias python=python3
   alias pip=pip3
   ```

   **Windows** (system environment variables):
   - Add {{python_install_path}} to Path
   - Add {{python_install_path}}\Scripts to Path

3. Verify:
   ```bash
   python --version
   pip --version
   ```

## Constraints
- Only responsible for environment variable configuration, not Python installation
- Requires terminal restart to take effect after configuration
- Idempotent: check if correctly configured if already set, do not rewrite
