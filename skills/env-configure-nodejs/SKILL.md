---
name: env-configure-nodejs
description: >-
  Use this skill when the user wants to configure Node.js environment variables and add Node.js to system PATH.
version: 1.0.0
displayName: Configure Node.js Environment Variables
domain: env
action: configure
object: nodejs
tags: [env, nodejs, node, config, path]
type: SKILL
inputs:
  - name: node_install_path
    type: string
    required: false
    description: Node.js installation path (auto-detect if not specified)
---
# Configure Node.js Environment Variables

## Purpose

Configure Node.js environment variables and add Node.js executables to system PATH only. Does not handle npm registry configuration.

## Trigger Conditions

Use this Skill when:
- Node.js is installed and needs to be added to PATH
- User needs node and npm commands accessible from command line
- User wants to verify Node.js installation path

## Prerequisites

- Node.js is installed on the system

## Execution Steps

### Step 1: Verify Prerequisites

Before attempting configuration:
- **Check if Node.js is installed**: Run `node --version`. If not found and `node_install_path` is not provided, inform user: "Node.js is not installed or not in PATH. Please install Node.js first or provide the installation path." Stop and do not proceed.
- If prerequisites are not met, inform user and stop.

### Step 2: Detect Node.js Installation

If `node_install_path` parameter is not provided:
- Locate Node.js installation using system-specific methods
- Check common installation directories
- Verify both node and npm executables exist
- If multiple versions exist, identify the active version
- If Node.js is not found, inform user and stop

### Step 3: Check Current Configuration (Idempotency)

Before making changes:
- Check if Node.js installation directory is already in PATH
- Check if node command is accessible
- Check if npm command is accessible
- If all are correctly configured, inform user: "Node.js environment variables are already configured correctly. No changes needed." and stop.

### Step 4: Add Node.js to PATH

Ensure Node.js executables are accessible:
- Add Node.js installation directory to PATH
- Include both node and npm locations
- Avoid duplicate entries in PATH
- Use appropriate path separator for the platform (semicolon for Windows, colon for macOS/Linux)

### Step 5: Verify Configuration

After configuration:
- Verify Node.js is accessible: `node --version`
- Verify npm is accessible: `npm --version`
- Confirm PATH configuration is correct

### Step 6: Inform User

- Confirm Node.js environment variables have been configured
- Provide version information for node and npm
- Remind user that terminal restart may be required for changes to take effect
- If npm registry configuration is needed, suggest using `env-configure-npm` skill

## Constraints

- **Single Responsibility**: Only configures Node.js PATH environment variables. Does not configure npm registry or other npm settings.
- **Idempotent**: Check first, configure only if needed. If already configured correctly, do nothing.
- **Prerequisite Check**: If Node.js is not installed, inform user and stop.
- User-level environment variables only

## Error Handling

- **Node.js not installed**: "Node.js is not installed or not accessible. Please install Node.js first or provide the installation path."
- **Invalid installation path**: "The provided path does not contain node executable. Please verify the installation path."
- **Already configured**: "Node.js environment variables are already configured correctly. No action needed."

## Related Skills

- `env-configure-npm` - Configure npm registry (separate responsibility)
- `env-configure-pnpm` - Configure pnpm package manager
- `env-configure-path` - Generic path configuration alternative
