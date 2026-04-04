---
name: env-configure-nodejs
description: >-
  Use this skill when the user wants to configure Node.js environment variables or set up Node environment variables.
version: 1.0.0
displayName: Configure Node.js Environment Variables
domain: env
action: configure
object: nodejs
tags: [env, nodejs, node, npm, config]
type: SKILL
inputs:
  - name: node_install_path
    type: string
    required: false
    description: Node.js installation path (auto-detect if not specified)
---
# Configure Node.js Environment Variables

## Trigger Conditions
Use when Node.js is installed and environment variables need to be configured.

## Prerequisites
- Node.js is installed

## Execution Steps
1. Detect Node.js installation path:
   ```bash
   which node  # macOS / Linux
   where node  # Windows
   ```

2. Configure environment variables:

   **macOS / Linux** (write to ~/.bashrc or ~/.zshrc):
   ```bash
   export PATH={{node_install_path}}/bin:$PATH
   ```

   **Windows** (system environment variables):
   - Add {{node_install_path}} to Path

3. Verify:
   ```bash
   node --version
   npm --version
   ```

## Constraints
- Only responsible for environment variable configuration, not Node.js installation
- Requires terminal restart or re-login to take effect after configuration
- Idempotent: check if correctly configured if already set, do not rewrite
