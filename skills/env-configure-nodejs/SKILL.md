---
name: env-configure-nodejs
description: >-
  Configure Node.js environment variables and add Node.js to PATH.
  Invoke when user needs Node.js commands accessible from command line.
  Auto-detects Node.js installation if path not specified.
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
- Check if Node.js is installed
- If not installed and path not provided, inform user and stop

### Step 2: Detect Node.js Installation

If `node_install_path` parameter is not provided:
- Locate Node.js installation using system-specific methods
- Verify both node and npm executables exist
- If multiple versions exist, identify the active version

### Step 3: Check Current Configuration (Idempotency)

Before making changes:
- Check if Node.js installation directory is already in PATH
- Check if node and npm commands are accessible
- If already configured correctly, inform user and stop

### Step 4: Add Node.js to PATH

Ensure Node.js executables are accessible:
- Add Node.js installation directory to PATH
- Avoid duplicate entries in PATH

### Step 5: Verify Configuration

After configuration:
- Verify Node.js is accessible
- Verify npm is accessible
- Confirm PATH configuration is correct

### Step 6: Inform User

- Confirm Node.js environment variables have been configured
- Provide version information for node and npm
- Remind user that terminal restart may be required

## Constraints

- **Single Responsibility**: Only configures Node.js PATH environment variables, not npm registry or other settings
- **Idempotent**: Check first, configure only if needed
- **Prerequisite Check**: If Node.js is not installed, inform user and stop
- User-level environment variables only

## Error Handling

- **Node.js not installed**: Inform user Node.js is not installed or not accessible
- **Invalid installation path**: Inform user provided path does not contain node executable
- **Already configured**: Inform user Node.js environment variables are already configured correctly

## Related Skills

- `env-configure-npm` - Configure npm registry (separate responsibility)
- `env-configure-pnpm` - Configure pnpm package manager
- `env-configure-path` - Generic path configuration alternative
